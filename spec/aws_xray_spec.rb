require 'spec_helper'
require 'timeout'

RSpec.describe Aws::Xray do
  before do
    allow(Aws::Xray.config).to receive(:client_options).and_return(client_options)
  end
  let(:client_options) { { sock: io } }
  let(:io) { Aws::Xray::TestSocket.new }

  describe '.trace' do
    context 'when succeed' do
      it 'starts tracing' do
        Aws::Xray.trace(name: 'test') {}
        expect(io.tap(&:rewind).read.split("\n").size).to eq(2)
      end
    end

    context 'when the name is missing' do
      around do |ex|
        back, Aws::Xray.config.name = Aws::Xray.config.name, nil
        ex.run
        Aws::Xray.config.name = back
      end

      it 'raises MissingNameError' do
        expect { Aws::Xray.trace {} }.to raise_error(Aws::Xray::MissingNameError)
      end
    end

    context 'when timeout error is raised' do
      it 'captures the error' do
        expect {
          Aws::Xray.trace(name: 'test') do
            Timeout.timeout(0.01) do
              sleep 0.03
            end
          end
        }.to raise_error(Timeout::Error)
        sent_jsons = io.tap(&:rewind).read.split("\n")
        expect(sent_jsons.size).to eq(2)

        body = JSON.parse(sent_jsons[1])
        expect(body['fault']).to eq(true)
      end
    end
  end

  describe '.overwrite' do
    context 'when the context is not set' do
      it 'does nothing' do
        expect { Aws::Xray.overwrite(name: 'overwrite') { } }.not_to raise_error

        sent_jsons = io.tap(&:rewind).read.split("\n")
        expect(sent_jsons.size).to eq(0)
      end
    end

    context 'when the context is set' do
      it 'overwrites name' do
        Aws::Xray.trace(name: 'test') do
          Aws::Xray.overwrite(name: 'overwrite') do
            Aws::Xray::Context.current.child_trace(name: 'name1', remote: false) {}
          end
        end

        sent_jsons = io.tap(&:rewind).read.split("\n")
        expect(sent_jsons.size).to eq(4)
        overwrote_one = JSON.parse(sent_jsons[1])

        expect(overwrote_one['name']).to eq('overwrite')
      end
    end
  end
end
