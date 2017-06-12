require 'spec_helper'

RSpec.describe Aws::Xray::Client do
  describe '#send_segment' do
    def build_server
      s = UDPSocket.new
      s.bind('127.0.0.1', 0)
      s
    end
    let(:segment) { double('segment', to_json: payload.to_json) }
    let(:payload) { { 'id' => 'abc' } }

    context 'success case' do
      it 'sends given segment' do
        s = build_server
        client = described_class.new(host: '127.0.0.1', port: s.addr[1])

        client.send_segment(segment)

        sent = s.recvfrom(1024)[0]
        expect(sent.split("\n").size).to eq(2)

        header, body = sent.split("\n").map {|e| JSON.parse(e) }
        expect(header).to eq('format' => 'json', 'version' => 1)
        expect(body).to eq(payload)
      end
    end

    context 'when too large payload is about to sent' do
      # Build as much as large payload to occur Errno::EMSGSIZE.
      # This is not platform compatible solution though...
      let(:payload) { { 'data' => 'abc' * 100000 } }

      it 'ignores system call erros' do
        s = build_server
        client = described_class.new(host: '127.0.0.1', port: s.addr[1])

        expect { client.send_segment(segment) }.to output(/Failed to send a segment/).to_stderr
      end
    end

    context 'when invalid hostname is specified' do
      it 'ignores socket errors' do
        client = described_class.new(host: 'aws-xray-gem-invalid-host-name', port: 8000)
        expect { client.send_segment(segment) }.to output(/Failed to send a segment/).to_stderr
      end
    end

    context 'when invalid port is specified' do
      it 'ignores socket errors' do
        client = described_class.new(host: '127.0.0.1', port: 0)
        expect { client.send_segment(segment) }.to output(/Failed to send a segment/).to_stderr
      end
    end
  end
end
