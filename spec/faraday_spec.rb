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
    def a.send(body, _); write(body); end
    a
  end
  let(:trace_header) { Aws::Xray::TraceHeader.new(root: '1-67891233-abcdef012345678912345678') }


  it do
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

    expect(res.body).to eq("Root=1-67891233-abcdef012345678912345678;Sampled=1;Parent=#{body['id']}")
  end

  it do
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
