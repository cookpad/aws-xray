require 'spec_helper'

RSpec.describe Aws::Xray::Rack do
  let(:env) { { 'HTTP_X_AMZN_TRACE_ID' => 'Root=1-67891233-abcdef012345678912345678;Parent=53995c3f42cd8ad8' } }
  let(:name) { 'test-app' }
  let(:io) do
    a = StringIO.new
    def a.send(body, _); write(body); end
    a
  end

  describe 'base tracing' do
    let(:app) { ->(_) { [200, {}, ['hello']] } }

    it 'calls original app and adds formated trace header value and sends base segment' do
      stack = described_class.new(app, name: name, client_options: { sock: io })
      status, headers, body = stack.call(env)

      expect(status).to eq(200)
      expect(body).to eq(['hello'])
      expect(headers).to eq('X-Amzn-Trace-Id' => 'Root=1-67891233-abcdef012345678912345678;Sampled=1;Parent=53995c3f42cd8ad8')

      io.rewind
      # Expected format is 2 lines of json string: http://docs.aws.amazon.com/xray/latest/devguide/xray-api.html
      sent_jsons = io.read.split("\n")
      expect(sent_jsons.size).to eq(2)
      header_json, body_json = *sent_jsons
      expect(JSON.parse(header_json)).to eq("format" => "json", "version" => 1)

      body = JSON.parse(body_json)
      expect(body['name']).to eq(name)
      expect(body['id']).to match(/\A[0-9a-fA-F]{16}\z/)
      expect(body['trace_id']).to eq('1-67891233-abcdef012345678912345678')
      expect(body['parent_id']).to eq('53995c3f42cd8ad8')
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
      -> (_) {
        Aws::Xray::Context.current.child_trace(remote: false, name: 'funccall_f') do
          # Do something like function calling or DB access
        end
        [200, {}, ['hello']]
      }
    end

    it 'sends both base segment and sub segment' do
      stack = described_class.new(app, name: name, client_options: { sock: io })
      status, headers, body = stack.call(env)

      expect(status).to eq(200)
      expect(body).to eq(['hello'])
      expect(headers).to eq('X-Amzn-Trace-Id' => 'Root=1-67891233-abcdef012345678912345678;Sampled=1;Parent=53995c3f42cd8ad8')

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
    let(:test_error) { Class.new(StandardError) }
    let(:app) { ->(_) { raise test_error } }

    it 'calls original app and adds formated trace header value and sends base segment' do
      stack = described_class.new(app, name: name, client_options: { sock: io })
      expect { stack.call(env) }.to raise_error(test_error)

      io.rewind
      sent_jsons = io.read.split("\n")
      expect(sent_jsons.size).to eq(2)
      _, body_json = *sent_jsons

      body = JSON.parse(body_json)
      expect(body['name']).to eq(name)
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
end
