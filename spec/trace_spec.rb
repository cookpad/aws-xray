require 'spec_helper'
require 'time'

RSpec.describe Aws::Xray::Trace do
  context 'with parent and sampled' do
    let(:v) { 'Root=1-5759e988-bd862e3fe1be46a994272793;Parent=53995c3f42cd8ad8;Sampled=1' }

    it 'created' do
      r = described_class.build_from_header_value(v)
      expect(r.root).to eq('1-5759e988-bd862e3fe1be46a994272793')
      expect(r.parent).to eq('53995c3f42cd8ad8')
      expect(r.sampled?).to eq(true)
    end

    it 'dumped' do
      r = described_class.build_from_header_value(v)
      expected = 'Root=1-5759e988-bd862e3fe1be46a994272793;Sampled=1;Parent=53995c3f42cd8ad8'
      expect(r.to_header_value).to eq(expected)
    end
  end

  describe '.generate' do
    it 'returns newly created trace header' do
      now = Time.parse('2017/01/01 00:00:00Z')
      r = described_class.generate(now)
      epoch = r.root.scan(/\A1-([0-9A-Fa-f]+)-/).first.first
      expect(epoch.to_i(16)).to eq(now.to_i)
    end
  end
end
