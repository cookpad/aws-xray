require 'spec_helper'

RSpec.describe Aws::Xray::Hooks::NetHttp do
  before do
    Thread.abort_on_exception = true
    allow(Aws::Xray.config).to receive(:client_options).and_return(sock: io)
  end

  let(:io) { Aws::Xray::TestSocket.new }
  let(:trace) { Aws::Xray::Trace.new(root: '1-67891233-abcdef012345678912345678', sampled: true) }
  let(:host) { '127.0.0.1' }
  let(:server) { TCPServer.new(0) }
  let(:port) { server.addr[1] }
  let(:queue) { Queue.new }

  def build_server_thread
    Thread.new do
      while s = server.accept
        queue.push(s.recv(1024))
        s.write("HTTP/1.1 200\r\nContent-Type: text/html\r\n\r\n\Hello world!")
        s.close
      end
    end
  end

  def build_client_thread(&block)
    Thread.new(block) do
      Aws::Xray.trace(name: 'test-app', trace: trace) { block.call }
      # For waiting sending segments in this thread.
      queue.push(nil)
    end
  end

  it 'monkey patchs net/http and records requests and responses' do
    server_thread = build_server_thread
    client_thread = build_client_thread do
      Net::HTTP.start(host, port) do |http|
        uri = URI("http://#{host}:#{port}/hello")
        response = http.request(Net::HTTP::Get.new(uri, { 'X-Aws-Xray-Name' => 'target-app' }))
        queue.push(response)
      end
    end

    request_string, response, _ = queue.pop, queue.pop, queue.pop
    expect(request_string).to match(/X-Amzn-Trace-Id/)
    expect(response.code).to eq('200')

    sent_jsons = io.tap(&:rewind).read.split("\n")
    expect(sent_jsons.size).to eq(4)
    body = JSON.parse(sent_jsons[1])
    parent_body = JSON.parse(sent_jsons[3])

    expect(body['name']).to eq('target-app')
    expect(body['id']).to match(/\A[0-9a-fA-F]{16}\z/)
    expect(body['parent_id']).to eq(parent_body['id'])
    expect(body['trace_id']).to eq('1-67891233-abcdef012345678912345678')

    request_part = body['http']['request']
    expect(request_part['method']).to eq('GET')
    expect(request_part['url']).to eq("http://#{host}:#{port}/hello")
    expect(request_part['user_agent']).to match(/Ruby/)
    expect(body['http']['response']['status']).to eq(200)

    SegmentValidator.call(body.to_json)

    expect(body['metadata']['caller']['stack'].size).not_to eq(0)
    expect(body['metadata']['caller']['stack'].first).to match(
      'path' => 'lib/aws/xray/hooks/net_http.rb',
      'line' => be_a(String),
      'label' => 'in `block in request_with_aws_xray\'',
    )

    server_thread.kill
    client_thread.kill
  end

  it 'allows block style http request' do
    server_thread = build_server_thread
    client_thread = build_client_thread do
      Net::HTTP.start(host, port) do |http|
        uri = URI("http://#{host}:#{port}/hello")
        response = http.get(uri, { 'X-Aws-Xray-Name' => 'target-app' })
        queue.push(response)
      end
    end

    request_string, response, _ = queue.pop, queue.pop, queue.pop
    expect(request_string).to match(/X-Amzn-Trace-Id/)
    expect(response.code).to eq('200')

    sent_jsons = io.tap(&:rewind).read.split("\n")
    expect(sent_jsons.size).to eq(4)
    body = JSON.parse(sent_jsons[1])
    parent_body = JSON.parse(sent_jsons[3])

    expect(body['name']).to eq('target-app')
    expect(body['id']).to match(/\A[0-9a-fA-F]{16}\z/)
    expect(body['parent_id']).to eq(parent_body['id'])
    expect(body['trace_id']).to eq('1-67891233-abcdef012345678912345678')

    request_part = body['http']['request']
    expect(request_part['method']).to eq('GET')
    expect(request_part['url']).to eq("http://#{host}:#{port}/hello")
    expect(request_part['user_agent']).to match(/Ruby/)
    expect(body['http']['response']['status']).to eq(200)

    SegmentValidator.call(body.to_json)

    server_thread.kill
    client_thread.kill
  end

  it 'does not record twice with non-started net/http instance' do
    server_thread = build_server_thread
    client_thread = build_client_thread do
      http = Net::HTTP.new(host, port)
      response = http.get('/hello', { 'X-Aws-Xray-Name' => 'target-app' })
      queue.push(response)
    end

    request_string, response, _ = queue.pop, queue.pop, queue.pop
    expect(request_string).to match(/X-Amzn-Trace-Id/)
    expect(response.code).to eq('200')

    sent_jsons = io.tap(&:rewind).read.split("\n")
    expect(sent_jsons.size).to eq(4)

    server_thread.kill
    client_thread.kill
  end

  it 'returns net_http response even if disabled tracing' do
    server_thread = build_server_thread
    client_thread = build_client_thread do
      Aws::Xray.disable_trace(:net_http) do
        Net::HTTP.start(host, port) do |http|
          uri = URI("http://#{host}:#{port}/hello")
          response = http.get(uri, { 'X-Aws-Xray-Name' => 'target-app' })
          queue.push(response)
        end
      end
    end

    request_string, response, _ = queue.pop, queue.pop, queue.pop
    expect(request_string).not_to match(/X-Amzn-Trace-Id/)
    expect(response.code).to eq('200')

    sent_jsons = io.tap(&:rewind).read.split("\n")
    expect(sent_jsons.size).to eq(2)

    server_thread.kill
    client_thread.kill
  end

  describe 'exclude hosts about passing trace header' do
    context 'when string' do
      before { allow(Aws::Xray.config).to receive(:trace_header_excluded_hosts).and_return(['127.0.0.1']) }

      it 'does not pass trace header' do
        server_thread = build_server_thread
        client_thread = build_client_thread do
          http = Net::HTTP.new(host, port)
          response = http.get('/hello', { 'X-Aws-Xray-Name' => 'target-app' })
          queue.push(response)
        end

        request_string, response, _ = queue.pop, queue.pop, queue.pop
        expect(request_string).not_to match(/X-Amzn-Trace-Id/)
        expect(response.code).to eq('200')

        sent_jsons = io.tap(&:rewind).read.split("\n")
        expect(sent_jsons.size).to eq(4)

        server_thread.kill
        client_thread.kill
      end
    end

    context 'when regexp matches host' do
      before { allow(Aws::Xray.config).to receive(:trace_header_excluded_hosts).and_return([/.*\.0\.0\.1/]) }

      it 'does not pass trace header' do
        server_thread = build_server_thread
        client_thread = build_client_thread do
          http = Net::HTTP.new(host, port)
          response = http.get('/hello', { 'X-Aws-Xray-Name' => 'target-app' })
          queue.push(response)
        end

        request_string, response, _ = queue.pop, queue.pop, queue.pop
        expect(request_string).not_to match(/X-Amzn-Trace-Id/)
        expect(response.code).to eq('200')

        sent_jsons = io.tap(&:rewind).read.split("\n")
        expect(sent_jsons.size).to eq(4)

        server_thread.kill
        client_thread.kill
      end
    end

    context 'when regexp does not match host' do
      before { allow(Aws::Xray.config).to receive(:trace_header_excluded_hosts).and_return([/.*\.1\.1\.1/]) }

      it 'passes trace header' do
        server_thread = build_server_thread
        client_thread = build_client_thread do
          http = Net::HTTP.new(host, port)
          response = http.get('/hello', { 'X-Aws-Xray-Name' => 'target-app' })
          queue.push(response)
        end

        request_string, response, _ = queue.pop, queue.pop, queue.pop
        expect(request_string).to match(/X-Amzn-Trace-Id/)
        expect(response.code).to eq('200')

        sent_jsons = io.tap(&:rewind).read.split("\n")
        expect(sent_jsons.size).to eq(4)

        server_thread.kill
        client_thread.kill
      end
    end
  end
end
