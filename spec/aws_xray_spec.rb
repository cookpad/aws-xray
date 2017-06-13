require 'spec_helper'

RSpec.describe Aws::Xray do
  describe '.trace' do
    context 'when succeed' do
      before do
        allow(Aws::Xray.config).to receive(:client_options).and_return(client_options)
      end
      let(:client_options) { { sock: io } }
      let(:io) { Aws::Xray::TestSocket.new }

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
  end
end
