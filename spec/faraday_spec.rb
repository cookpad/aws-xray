require 'spec_helper'

RSpec.describe Aws::Xray::Faraday do
  let(:stubs) do
    Faraday::Adapter::Test::Stubs.new do |stub|
      stub.get('/foo') { |env| [200, {}, env.request_headers['X-Amzn-Trace-Id']] }
    end
  end
  let(:client) do
    Faraday.new(headers: headers) do |builder|
      builder.use Aws::Xray::Faraday
      builder.adapter :test, stubs
    end
  end
  let(:headers) { { 'Host' => 'target-app' } }
  let(:xray_client) { Aws::Xray::Client.new(sock: io) }
  let(:io) do
    a = StringIO.new
    def a.send(body, *); write(body); end
    a
  end
  let(:trace_header) { Aws::Xray::TraceHeader.new(root: '1-67891233-abcdef012345678912345678') }

  context 'without name option' do
    it 'uses host header value' do
      res = Aws::Xray::Context.with_new_context('test-app', xray_client, trace_header) do
        Aws::Xray::Context.current.base_trace do
          client.get('/foo')
        end
      end
      expect(res.status).to eq(200)
      expect(res.headers).to eq({})

      io.rewind
      sent_jsons = io.read.split("\n")
      expect(sent_jsons.size).to eq(4)
      header_json, body_json = sent_jsons[0..1]
      _, parent_body_json = sent_jsons[2..3]

      expect(JSON.parse(header_json)).to eq("format" => "json", "version" => 1)
      body = JSON.parse(body_json)
      parent_body = JSON.parse(parent_body_json)

      expect(body['name']).to eq('target-app')
      expect(body['id']).to match(/\A[0-9a-fA-F]{16}\z/)
      expect(body['parent_id']).to eq(parent_body['id'])
      expect(body['type']).to eq('subsegment')
      expect(body['trace_id']).to eq('1-67891233-abcdef012345678912345678')
      expect(Float(body['start_time'])).not_to eq(0)
      expect(Float(body['end_time'])).not_to eq(0)

      request_part = body['http']['request']
      expect(request_part['method']).to eq('GET')
      expect(request_part['url']).to eq('http:/foo')
      expect(request_part['user_agent']).to match(/Faraday/)
      expect(request_part['client_ip']).to be_nil
      expect(request_part).not_to have_key('x_forwarded_for')
      expect(request_part['traced']).to eq(false)

      expect(body['http']['response']['status']).to eq(200)
      expect(body['http']['response']['content_length']).to be_nil

      expect(res.body).to eq("Root=1-67891233-abcdef012345678912345678;Sampled=1;Parent=#{body['id']}")
    end
  end

  context 'when name option is given via builder' do
    it 'sets given name to trace name' do
      client = Faraday.new do |builder|
        builder.use Aws::Xray::Faraday, 'another-name'
        builder.adapter :test, stubs
      end

      res = Aws::Xray::Context.with_new_context('test-app', xray_client, trace_header) do
        Aws::Xray::Context.current.base_trace do
          client.get('/foo')
        end
      end
      expect(res.status).to eq(200)
      expect(res.headers).to eq({})

      io.rewind
      sent_jsons = io.read.split("\n")
      expect(sent_jsons.size).to eq(4)
      _, body_json = sent_jsons[0..1]

      body = JSON.parse(body_json)
      expect(body['name']).to eq('another-name')
    end
  end

  context 'when down-stream returns error' do
    context '5xx' do
      let(:stubs) do
        Faraday::Adapter::Test::Stubs.new do |stub|
          stub.get('/foo') { |env| [500, {}, 'fault'] }
        end
      end

      it 'traces remote fault' do
        res = Aws::Xray::Context.with_new_context('test-app', xray_client, trace_header) do
          Aws::Xray::Context.current.base_trace do
            client.get('/foo')
          end
        end
        expect(res.status).to eq(500)

        io.rewind
        sent_jsons = io.read.split("\n")
        _, body_json = sent_jsons[0..1]
        body = JSON.parse(body_json)

        expect(body['name']).to eq('target-app')
        expect(body['id']).to match(/\A[0-9a-fA-F]{16}\z/)
        expect(body['type']).to eq('subsegment')
        expect(body['trace_id']).to eq('1-67891233-abcdef012345678912345678')

        expect(body['error']).to eq(false)
        expect(body['throttle']).to eq(false)
        expect(body['fault']).to eq(true)

        e = body['cause']['exceptions'].first
        expect(e['id']).to match(/\A[0-9a-fA-F]{16}\z/)
        expect(e['message']).to eq('Got 5xx')
        expect(e['remote']).to eq(true)
        expect(e['stack'].size).to eq(10)
        expect(e['stack'].first['path']).to end_with('.rb')
      end
    end

    context '499' do
      # TODO
    end

    context '4xx' do
      # TODO
    end
  end

  context 'when API call raises an error' do
    let(:stubs) do
      Faraday::Adapter::Test::Stubs.new do |stub|
        stub.get('/foo') { |env| raise('test_error') }
      end
    end

    it 'traces remote fault' do
      expect {
        Aws::Xray::Context.with_new_context('test-app', xray_client, trace_header) do
          Aws::Xray::Context.current.base_trace do
            client.get('/foo')
          end
        end
      }.to raise_error('test_error')

      io.rewind
      sent_jsons = io.read.split("\n")
      expect(sent_jsons.size).to eq(4)
      sub_body = JSON.parse(sent_jsons[1])

      expect(sub_body['name']).to eq('target-app')
      expect(sub_body['id']).to match(/\A[0-9a-fA-F]{16}\z/)
      expect(sub_body['type']).to eq('subsegment')
      expect(sub_body['trace_id']).to eq('1-67891233-abcdef012345678912345678')

      expect(sub_body['error']).to eq(false)
      expect(sub_body['throttle']).to eq(false)
      expect(sub_body['fault']).to eq(true)

      e = sub_body['cause']['exceptions'].first
      expect(e['id']).to match(/\A[0-9a-fA-F]{16}\z/)
      expect(e['message']).to eq('test_error')
      expect(e['type']).to eq('RuntimeError')
      expect(e['remote']).to eq(false)
      expect(e['stack'].size).to eq(10)
      expect(e['stack'].first['path']).to end_with('.rb')

      body = JSON.parse(sent_jsons[3])

      expect(body['name']).to eq('test-app')
      expect(body['id']).to match(/\A[0-9a-fA-F]{16}\z/)
      expect(body).not_to have_key('type')
      expect(body['trace_id']).to eq('1-67891233-abcdef012345678912345678')

      expect(body['error']).to eq(false)
      expect(body['throttle']).to eq(false)
      expect(body['fault']).to eq(true)

      e = body['cause']['exceptions'].first
      expect(e['id']).to match(/\A[0-9a-fA-F]{16}\z/)
      expect(e['message']).to eq('test_error')
      expect(e['type']).to eq('RuntimeError')
      expect(e['remote']).to eq(false)
      expect(e['stack'].size).to eq(10)
      expect(e['stack'].first['path']).to end_with('.rb')
    end
  end
end
