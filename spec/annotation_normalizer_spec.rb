require 'spec_helper'

RSpec.describe Aws::Xray::AnnotationNormalizer do
  context 'when keys and values are ok' do
    let(:h) { { zip_code: 98101, internal2: false } }

    it 'passes' do
      expect(described_class.call(h)).to eq(zip_code: 98101, internal2: false)
    end
  end

  context 'when a key contains "-"' do
    let(:h) { { :"zip-code" => 98101, internal2: false } }

    it 'converts "-" to "_"' do
      expect(described_class.call(h)).to eq(zip_code: 98101, internal2: false)
    end
  end

  context 'when a key contains invalid characters' do
    let(:h) { { :"zip_code?あ" => 98101, internal2: false } }

    it 'removes them' do
      expect(described_class.call(h)).to eq(zip_code: 98101, internal2: false)
    end
  end

  context 'when a value is invalid type' do
    let(:h) { { zip_code: { num: 98101}, internal2: false } }

    it 'converts it to string' do
      expect(described_class.call(h)).to eq(zip_code: '{:num=>98101}', internal2: false)
    end
  end
end
