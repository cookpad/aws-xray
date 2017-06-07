require 'spec_helper'
require 'timeout'

RSpec.describe Aws::Xray::Context do
  describe 'thread safety' do
    let(:client) { double(:client, send: nil) }
    let(:trace) { Aws::Xray::Trace.generate }

    specify 'a context is not shared between threads' do
      described_class.with_new_context('test-app', client, trace) do
        expect(Aws::Xray::Context.current).to be_a(Aws::Xray::Context)
        expect {
          Thread.new { Aws::Xray::Context.current }.join
        }.to raise_error(Aws::Xray::Context::NotSetError)
      end
    end

    specify 'a context can be passed to another thread' do
      described_class.with_new_context('test-app', client, trace) do
        expect {
          Thread.new(Aws::Xray::Context.current.copy) {|context|
            Aws::Xray::Context.set_current(context)
            expect(Aws::Xray::Context.current).to be_a(Aws::Xray::Context)
          }.join
        }.not_to raise_error
      end
    end

    specify 'subsegments can be sent from multiple threads' do
      server = UDPSocket.new
      server.bind('127.0.0.1', 0)
      client = Aws::Xray::Client.new(host: server.addr[2], port: server.addr[1])

      described_class.with_new_context('test-app', client, trace) do
        Aws::Xray::Context.current.base_trace do
          threads = 100.times.map do |i|
            Thread.new(Aws::Xray::Context.current.copy) {|context|
              Aws::Xray::Context.set_current(context)
              Aws::Xray::Context.current.child_trace(name: i.to_s, remote: false) do |sub|
                # pass
              end
            }
          end
          threads.each(&:join)
        end
      end

      Timeout::timeout(5) do
        names = []
        100.times do
          header, body = server.recvfrom(1024 * 1024)[0].split("\n").map {|e| JSON.parse(e) }
          expect(header).to eq({'format' => 'json', 'version' => 1})
          name = body['name']
          expect(name).to match(/\A\d+\z/)
          expect(names).not_to include(name)
          names << name
        end
      end
    end
  end
end
