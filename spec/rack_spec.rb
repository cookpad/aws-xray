require 'spec_helper'

RSpec.describe Aws::Xray::Rack do
  include Rack::Test::Methods

  let(:env) { { 'HTTP_X_AMZN_TRACE_ID' => 'Root=1-67891233-abcdef012345678912345678;Parent=53995c3f42cd8ad8' } }
  let(:io) { Aws::Xray::TestSocket.new }

  describe 'base tracing' do
    let(:app) do
      builder = Rack::Builder.new
      builder.use described_class, client_options: { sock: io }
      builder.run ->(_) { [200, {}, ['hello']] }
      builder
    end

    it 'calls original app and adds formated trace header value and sends base segment' do
      get '/', {}, env

      expect(last_response.status).to eq(200)
      expect(last_response.body).to eq('hello')
      expect(last_response.headers).to include('X-Amzn-Trace-Id' => 'Root=1-67891233-abcdef012345678912345678;Sampled=1;Parent=53995c3f42cd8ad8')

      io.rewind
      # Expected format is 2 lines of json string: http://docs.aws.amazon.com/xray/latest/devguide/xray-api.html
      sent_jsons = io.read.split("\n")
      expect(sent_jsons.size).to eq(2)
      header_json, body_json = *sent_jsons
      expect(JSON.parse(header_json)).to eq("format" => "json", "version" => 1)

      body = JSON.parse(body_json)
      expect(body['name']).to eq('test-app')
      expect(body['id']).to match(/\A[0-9a-fA-F]{16}\z/)
      expect(body['trace_id']).to eq('1-67891233-abcdef012345678912345678')
      expect(body['parent_id']).to eq('53995c3f42cd8ad8')
      expect(body['service']['version']).to eq('deadbeef')
      expect(body['annotations']['hostname']).not_to be_empty
      expect(body['metadata']['tracing_sdk']['name']).to eq('aws-xray')
      # Test they are valid float value and are not 0.
      expect(Float(body['start_time'])).not_to eq(0)
      expect(Float(body['end_time'])).not_to eq(0)

      request_part = body['http']['request']
      expect(request_part).to have_key('x_forwarded_for')
      expect(request_part).not_to have_key('traced')

      expect(body['http']['response']['status']).to eq(200)
      expect(body['http']['response']['content_length']).to be_nil
    end
  end

  describe 'sub segment tracing' do
    let(:app) do
      builder = Rack::Builder.new
      builder.use described_class, client_options: { sock: io }
      builder.run -> (_) {
        Aws::Xray::Context.current.child_trace(remote: false, name: 'funccall_f') {}
        [200, {}, ['hello']]
      }
      builder
    end

    it 'sends both base segment and sub segment' do
      get '/', {}, env

      expect(last_response.status).to eq(200)
      expect(last_response.body).to eq('hello')
      expect(last_response.headers).to include('X-Amzn-Trace-Id' => 'Root=1-67891233-abcdef012345678912345678;Sampled=1;Parent=53995c3f42cd8ad8')

      io.rewind
      sent_jsons = io.read.split("\n")
      expect(sent_jsons.size).to eq(4)
      header_json, body_json = sent_jsons[0..1]
      _, parent_body_json = sent_jsons[2..3]

      expect(JSON.parse(header_json)).to eq("format" => "json", "version" => 1)
      body = JSON.parse(body_json)
      parent_body = JSON.parse(parent_body_json)

      expect(body['name']).to eq('funccall_f')
      expect(body['id']).to match(/\A[0-9a-fA-F]{16}\z/)
      expect(body['parent_id']).to eq(parent_body['id'])
      expect(body['type']).to eq('subsegment')
      expect(body['trace_id']).to eq('1-67891233-abcdef012345678912345678')
      expect(Float(body['start_time'])).not_to eq(0)
      expect(Float(body['end_time'])).not_to eq(0)
    end
  end

  describe 'error tracing' do
    context 'the rack app raised an error' do
      let(:test_error) { Class.new(StandardError) }
      let(:app) { ->(_) { raise test_error } }

      it 'calls original app and adds formated trace header value and sends base segment' do
        stack = described_class.new(app, client_options: { sock: io })
        expect { stack.call(env) }.to raise_error(test_error)

        io.rewind
        sent_jsons = io.read.split("\n")
        expect(sent_jsons.size).to eq(2)
        _, body_json = *sent_jsons

        body = JSON.parse(body_json)
        expect(body['name']).to eq('test-app')
        expect(body['id']).to match(/\A[0-9a-fA-F]{16}\z/)
        expect(body['trace_id']).to eq('1-67891233-abcdef012345678912345678')
        expect(body['parent_id']).to eq('53995c3f42cd8ad8')

        expect(body['error']).to eq(false)
        expect(body['throttle']).to eq(false)
        expect(body['fault']).to eq(true)
        expect(body['cause']).to be_a(Hash)
        expect(body['cause']).not_to be_empty
      end
    end

    context 'the rack app responded an error' do
      let(:test_error) { Class.new(StandardError) }
      let(:app) do
        builder = Rack::Builder.new
        builder.use described_class, client_options: { sock: io }
        builder.use Class.new {
          def initialize(app); @app = app; end
          def call(env)
            @app.call
          rescue
            [500, {}, ['error']]
          end
        }
        builder.run ->(_) { raise test_error.new('test error') }
        builder
      end

      it 'marks the segment as a error' do
        get '/'

        expect(last_response.status).to eq(500)
        expect(last_response.body).to eq('error')
        expect(last_response.headers).not_to include(
          'X-Amzn-Trace-Id' => 'Root=1-67891233-abcdef012345678912345678;Sampled=1;Parent=53995c3f42cd8ad8'
        )

        io.rewind
        sent_jsons = io.read.split("\n")
        expect(sent_jsons.size).to eq(2)

        body = JSON.parse(sent_jsons[1])
        expect(body['name']).to eq('test-app')
        expect(body['error']).to eq(false)
        expect(body['throttle']).to eq(false)
        expect(body['fault']).to eq(true)
        expect(body['cause']['exceptions'].size).to eq(1)

        e = body['cause']['exceptions'].first
        expect(e['message']).to eq('Got 5xx')
        expect(e['type']).to eq('http_response_error')
        expect(e['remote']).to eq(false)
        expect(e['truncated']).to be >= 0
        expect(e['skipped']).to be_nil
        expect(e['cause']).to be_nil
        expect(e['stack'].size).to be >= 1
      end
    end
  end

  describe 'path excluding' do
    let(:app) do
      builder = Rack::Builder.new
      builder.use described_class, excluded_paths: excluded_paths, client_options: { sock: io }
      builder.run ->(_) { [200, {}, ['hello']] }
      builder
    end

    context 'with strings' do
      let(:excluded_paths) { ['/health_check'] }

      it 'does not trace the request' do
        get '/health_check', {}, env
        expect(last_response.status).to eq(200)

        io.rewind
        expect(io.read).to be_empty
      end
    end

    context 'with regexps' do
      let(:excluded_paths) { [/check/] }

      it 'does not trace the request' do
        get '/health_check', {}, env
        expect(last_response.status).to eq(200)

        io.rewind
        expect(io.read).to be_empty
      end
    end
  end
end
