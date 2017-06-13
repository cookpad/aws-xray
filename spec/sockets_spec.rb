require 'spec_helper'

RSpec.describe 'Sockets' do
  describe Aws::Xray::NullSocket do
    before do
      allow(Aws::Xray.config).to receive(:client_options).and_return(sock: Aws::Xray::NullSocket.new)
    end

    it 'does nothing' do
      expect { Aws::Xray.trace(name: 'test') {} }.not_to raise_error
    end
  end

  describe Aws::Xray::IoSocket do
    before do
      allow(Aws::Xray.config).to receive(:client_options).and_return(sock: sock)
    end
    let(:sock) { Aws::Xray::IoSocket.new(io) }
    let(:io) { StringIO.new }

    it 'uses given IO object' do
      Aws::Xray.trace(name: 'test') {}
      expect(io.tap(&:rewind).read.split("\n").size).to eq(2)
    end
  end
end
