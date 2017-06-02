require 'spec_helper'

RSpec.describe Aws::Xray::Segment do
  let(:trace) { Aws::Xray::Trace.new(root: '1-67891233-abcdef012345678912345678', parent: 'd5058bbe22392c37') }

  describe 'serialization' do
    it 'serialized properly' do
      segment = described_class.build('test-app', trace)
      expect(segment.to_h).to match(
        name: 'test-app',
        id: /\A[0-9A-Fa-f]{16}\z/,
        trace_id: '1-67891233-abcdef012345678912345678',
        service: { version: 'deadbeef' },
        annotations: a_kind_of(Hash),
        metadata: a_kind_of(Hash),
        start_time: a_kind_of(Float),
        in_progress: true,
        parent_id: 'd5058bbe22392c37',
      )
      segment.finish
      expect(segment.to_h.has_key?(:in_progress)).to eq(false)
      expect(segment.to_h.has_key?(:end_time)).to eq(true)
    end

    context 'when illegal bytes are included in HTTP request' do
      # \x61 = a, \xe3 = illegal bytes, \x62 = b, \x63 = c
      let(:url) { "/user?name=\x61\xe3\x62\x63" }
      let(:request) { Aws::Xray::Request.build(method: 'GET', url: url) }

      it 'serialized successfully' do
        segment = described_class.build('test-app', trace)
        segment.set_http_request(request)
        body = JSON.parse(segment.to_json)
        expect(body['name']).to eq('test-app')
        # \uFFFD is default unicode character in replacing illegal bytes.
        expect(body['http']['request']['url']).to eq("/user?name=a\uFFFDbc")
      end
    end
  end

  describe '#add_annotation' do
    it 'sets annotation' do
      segment = described_class.build('test-app', trace)
      segment.add_annotation(server: 'web-001')
      expect(segment.to_h[:annotations][:server]).to eq('web-001')
    end
  end
end
