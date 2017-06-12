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

    context 'when passed exception object' do
      it 'dumps as a Hash' do
        h = described_class.new(true, true, true, exception, false, nil).to_h
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
        expect(e[:truncated]).to be >= 0
        expect(e[:skipped]).to eq(0)
        expect(e[:cause]).to be_nil
        expect(e[:stack].size).to be >= 1

        stack = e[:stack].first
        expect(stack[:path]).to eq('spec/error_spec.rb')
        expect(stack[:line]).to eq('8')
        expect(stack[:label]).to match(/in `block .+'/)
      end
    end

    context 'when passed cause object' do
      let(:cause) { Aws::Xray::Cause.new(stack: caller, message: 'xxx', type: 'test') }

      it 'dumps as a Hash' do
        h = described_class.new(false, false, true, nil, true, cause).to_h
        cause = h[:cause]
        expect(cause[:working_directory]).to match(/aws-xray/)
        expect(cause[:paths]).to eq([])

        expect(cause[:exceptions].size).to eq(1)
        e = cause[:exceptions].first
        expect(e[:id]).to match(/\A[0-9A-Za-z]{16}\z/)
        expect(e[:message]).to eq('xxx')
        expect(e[:type]).to eq('test')
        expect(e[:remote]).to eq(true)
        expect(e[:truncated]).to be >= 0
        expect(e[:stack].size).to be >= 1
      end
    end

    context 'when current working directory has been unlinked' do
      let(:path) { File.expand_path('../tmp/test_dir', __dir__) }

      around do |ex|
        FileUtils.mkdir_p(path)
        Dir.chdir(path)
        ex.run
        Dir.chdir(File.expand_path('../', __dir__))
        FileUtils.rm_rf(path)
      end

      it 'fallbacks to root directory' do
        FileUtils.rm_rf(path)
        h = nil
        expect {
          h = described_class.new(false, false, true, exception, false, nil).to_h
        }.not_to raise_error

        expect(h[:cause][:working_directory]).to eq('/')
      end
    end
  end
end
