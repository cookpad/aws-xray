require 'spec_helper'

RSpec.describe Aws::Xray::AnnotationValidator do
  context 'when keys and values are ok' do
    let(:h) { { zip_code: 98101, internal2: false } }

    it 'passes' do
      expect { described_class.call(h) }.not_to raise_error
    end
  end

  context 'when keys are ng' do
    let(:h) { { "zip-code": 98101, internal: false } }

    it 'raises' do
      expect { described_class.call(h) }.to raise_error(RuntimeError)
    end
  end

  context 'when keys are ng' do
    let(:h) { { "zipcode?": 98101, internal: false } }

    it 'raises' do
      expect { described_class.call(h) }.to raise_error(RuntimeError)
    end
  end

  context 'when values are ng' do
    let(:h) { { zip_code: { num: 98101}, internal: false } }

    it 'raises' do
      expect { described_class.call(h) }.to raise_error(RuntimeError)
    end
  end
end
