require 'spec_helper'

RSpec.describe Aws::Xray::Configuration do
  describe '#client_options' do
    before { allow(ENV).to receive(:[]).and_return(location) }

    context 'when valid hostname and port are given' do
      let(:location) { 'xray:2000' }

      it 'returns host and port' do
        expect(Aws::Xray::Configuration.new.client_options).to eq(host: 'xray', port: 2000)
      end
    end

    context 'when invalid hostname and port format is given' do
      let(:location) { ':::' }

      it 'returns default one' do
        expect(Aws::Xray::Configuration.new.client_options).to match(sock: be_a(Aws::Xray::NullSocket))
      end
    end

    context 'when only hostname is given' do
      let(:location) { 'xray' }

      it 'returns default one' do
        expect(Aws::Xray::Configuration.new.client_options).to match(sock: be_a(Aws::Xray::NullSocket))
      end
    end

    context 'when only port is given' do
      let(:location) { ':2000' }

      it 'returns default one' do
        expect(Aws::Xray::Configuration.new.client_options).to match(sock: be_a(Aws::Xray::NullSocket))
      end
    end

    context 'when empty string is given' do
      let(:location) { '' }

      it 'returns default one' do
        expect(Aws::Xray::Configuration.new.client_options).to match(sock: be_a(Aws::Xray::NullSocket))
      end
    end

    context 'when nothing is given' do
      let(:location) { nil }

      it 'returns default one' do
        expect(Aws::Xray::Configuration.new.client_options).to match(sock: be_a(Aws::Xray::NullSocket))
      end
    end
  end

  describe '#excluded_paths' do
    before { allow(ENV).to receive(:[]).and_return(value) }

    context 'when valid value is given' do
      let(:value) { 'revision,app/health' }

      it 'returns parsed value' do
        expect(Aws::Xray::Configuration.new.excluded_paths).to eq(%w[revision app/health])
      end
    end

    context 'when invalid value is given' do
      let(:value) { ',,,,' }

      it 'returns parsed value' do
        expect(Aws::Xray::Configuration.new.excluded_paths).to eq([])
      end
    end

    context 'when the option is not specified' do
      let(:value) { nil }

      it 'returns parsed value' do
        expect(Aws::Xray::Configuration.new.excluded_paths).to eq([])
      end
    end
  end
end
