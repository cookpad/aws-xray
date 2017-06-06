require 'spec_helper'

RSpec.describe Aws::Xray::Request do
  describe 'serialization' do
    let(:request) { described_class.build(method: 'GET', url: url) }
    let(:body) { JSON.parse(request.to_h.to_json) }

    context 'when illegal bytes are included in HTTP request' do
      # \x61 = a, \xe3 = illegal bytes, \x62 = b, \x63 = c
      let(:url) { "/users/\x61\xe3\x62\x63/" }

      it 'serialized successfully' do
        # \uFFFD is default unicode character in replacing illegal bytes.
        expect(body['url']).to eq("/users/a\uFFFDbc/")
      end
    end

    context 'when request parameters are given' do
      let(:url) { '/user?name=alice' }

      it 'drops the request parameters' do
        expect(body['url']).to eq('/user')
      end
    end

    context 'when a given uri has fragment part' do
      let(:url) { '/user?name=alice#token=xxx' }

      it 'drops the fragment part' do
        expect(body['url']).to eq('/user')
      end
    end
  end
end
