require 'spec_helper'

RSpec.describe Aws::Xray::Error do
  describe '#to_h' do
    let(:exception) do
      e = nil
      begin
        raise 'aaa'
      rescue => ex
        e = ex
      end
      e
    end

    it 'dumps as a Hash' do
      h = described_class.new(true, true, true, exception, false).to_h
      expect(h[:error]).to eq(true)
      expect(h[:throttle]).to eq(true)
      expect(h[:fault]).to eq(true)

      cause = h[:cause]
      expect(cause[:working_directory]).to match(/aws-xray/)
      expect(cause[:paths]).to eq([])

      expect(cause[:exceptions].size).to eq(1)
      e = cause[:exceptions].first
      expect(e[:id]).to match(/\A[0-9A-Za-z]{16}\z/)
      expect(e[:message]).to eq('aaa')
      expect(e[:type]).to eq('RuntimeError')
      expect(e[:remote]).to eq(false)
      expect(e[:truncated]).to be > 0
      expect(e[:skipped]).to eq(0)
      expect(e[:cause]).to be_nil
      expect(e[:stack].size).to eq(10)

      stack = e[:stack].first
      expect(stack[:path]).to eq('spec/error_spec.rb')
      expect(stack[:line]).to eq('8')
      expect(stack[:label]).to match(/in `block .+'/)
    end
  end
end
