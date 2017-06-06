require 'spec_helper'

RSpec.describe Aws::Xray::Request do
  describe 'serialization' do
    context 'when illegal bytes are included in HTTP request' do
      # \x61 = a, \xe3 = illegal bytes, \x62 = b, \x63 = c
      let(:url) { "/user?name=\x61\xe3\x62\x63" }
      let(:request) { described_class.build(method: 'GET', url: url) }

      it 'serialized successfully' do
        body = JSON.parse(request.to_h.to_json)
        # \uFFFD is default unicode character in replacing illegal bytes.
        expect(body['url']).to eq("/user?name=a\uFFFDbc")
      end
    end
  end
end
