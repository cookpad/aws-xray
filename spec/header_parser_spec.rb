require 'spec_helper'

RSpec.describe Aws::Xray::HeaderParser do
  context 'without parent' do
    let(:v) { 'Root=1-5759e988-bd862e3fe1be46a994272793;Sampled=1' }

    it 'parses' do
      r = described_class.parse(v)
      expect(r).to eq('Root' => '1-5759e988-bd862e3fe1be46a994272793', 'Sampled' => '1')
    end
  end

  context 'with parent' do
    let(:v) { 'Root=1-5759e988-bd862e3fe1be46a994272793;Parent=53995c3f42cd8ad8;Sampled=1' }

    it 'parses' do
      r = described_class.parse(v)
      expect(r).to eq('Root' => '1-5759e988-bd862e3fe1be46a994272793', 'Sampled' => '1', 'Parent' => '53995c3f42cd8ad8')
    end
  end

  context 'with custom values' do
    let(:v) { 'Root=1-5759e988-bd862e3fe1be46a994272793;Parent=53995c3f42cd8ad8;MyField=abc' }

    it 'parses' do
      r = described_class.parse(v)
      expect(r).to eq('Root' => '1-5759e988-bd862e3fe1be46a994272793', 'Parent' => '53995c3f42cd8ad8', 'MyField' => 'abc')
    end
  end

  context 'with extra delimiter' do
    let(:v) { 'Root=1-5759e988-bd862e3fe1be46a994272793;Sampled=1;' }

    it 'parses' do
      r = described_class.parse(v)
      expect(r).to eq('Root' => '1-5759e988-bd862e3fe1be46a994272793', 'Sampled' => '1')
    end
  end

  context 'with extra spaces' do
    let(:v) { ' Root=1-5759e988-bd862e3fe1be46a994272793;Sampled=1 ' }

    it 'parses' do
      r = described_class.parse(v)
      expect(r).to eq('Root' => '1-5759e988-bd862e3fe1be46a994272793', 'Sampled' => '1')
    end
  end

  context 'with extra spaces between elements' do
    let(:v) { ' Root=1-5759e988-bd862e3fe1be46a994272793; Sampled=1 ' }

    it 'parses' do
      r = described_class.parse(v)
      expect(r).to eq('Root' => '1-5759e988-bd862e3fe1be46a994272793', 'Sampled' => '1')
    end
  end

  context 'with extra delimiters between elements' do
    let(:v) { 'Root=1-5759e988-bd862e3fe1be46a994272793;;;Sampled=1 ' }

    it 'parses' do
      r = described_class.parse(v)
      expect(r).to eq('Root' => '1-5759e988-bd862e3fe1be46a994272793', 'Sampled' => '1')
    end
  end

  context 'with broken value (only key)' do
    let(:v) { 'Root' }

    it 'parses' do
      r = described_class.parse(v)
      expect(r).to eq({})
    end
  end

  context 'with broken value (only value)' do
    let(:v) { '=1-5759e988-bd862e3fe1be46a994272793' }

    it 'parses' do
      r = described_class.parse(v)
      expect(r).to eq({})
    end
  end

  context 'with broken value (only equal mark)' do
    let(:v) { '=' }

    it 'parses' do
      r = described_class.parse(v)
      expect(r).to eq({})
    end
  end

  context 'with broken value (only delimiter mark)' do
    let(:v) { ';' }

    it 'parses' do
      r = described_class.parse(v)
      expect(r).to eq({})
    end
  end

  context 'with broken value (only delimiter and equal mark)' do
    let(:v) { '=;' }

    it 'parses' do
      r = described_class.parse(v)
      expect(r).to eq({})
    end
  end

  context 'with broken value (equal_marks)' do
    let(:v) { '= ====' }

    it 'parses' do
      r = described_class.parse(v)
      expect(r).to eq({})
    end
  end
end
