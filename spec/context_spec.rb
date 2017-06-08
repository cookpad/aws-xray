require 'spec_helper'
require 'timeout'

RSpec.describe Aws::Xray::Context do
  let(:trace) { Aws::Xray::Trace.generate }

  describe 'thread safety' do
    let(:client) { double(:client, send: nil) }
    before { allow(client).to receive(:copy).and_return(client) }

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

  describe '#overwrite_sub_segment' do
    let(:client) { Aws::Xray::Client.new(sock: io) }
    let(:io) { Aws::Xray::TestSocket.new }

    context 'when not set' do
      it 'does not overwrite' do
        Aws::Xray::Context.with_new_context('test-app', client, trace) do
          Aws::Xray::Context.current.base_trace do
            Aws::Xray::Context.current.child_trace(name: 'name1', remote: false) do
              Aws::Xray::Context.current.child_trace(name: 'name2', remote: false) {}
            end
          end
        end

        sent_jsons = io.tap(&:rewind).read.split("\n")
        expect(sent_jsons.size).to eq(6)
        normal_one = JSON.parse(sent_jsons[1])
        overwrote_one = JSON.parse(sent_jsons[3])

        expect(overwrote_one['name']).to eq('name1')
        expect(normal_one['name']).to eq('name2')
        expect(overwrote_one['parent_id']).to eq(normal_one['parent_id'])
      end
    end

    context 'when set' do
      it 'overwrites sub segment at once' do
        Aws::Xray::Context.with_new_context('test-app', client, trace) do
          Aws::Xray::Context.current.base_trace do
            Aws::Xray::Context.current.overwrite_sub_segment(name: 'overwrite') do
              Aws::Xray::Context.current.child_trace(name: 'name1', remote: false) do
                Aws::Xray::Context.current.child_trace(name: 'name2', remote: false) {}
              end
            end
          end
        end

        sent_jsons = io.tap(&:rewind).read.split("\n")
        expect(sent_jsons.size).to eq(6)
        normal_one = JSON.parse(sent_jsons[1])
        overwrote_one = JSON.parse(sent_jsons[3])

        expect(overwrote_one['name']).to eq('overwrite')
        expect(normal_one['name']).to eq('name2')
        expect(overwrote_one['parent_id']).to eq(normal_one['parent_id'])
      end
    end
  end
end
