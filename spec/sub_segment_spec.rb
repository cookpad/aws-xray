require 'spec_helper'

RSpec.describe Aws::Xray::SubSegment do
  let(:trace_header) { Aws::Xray::TraceHeader.new(root: '1-67891233-abcdef012345678912345678', parent: 'd5058bbe22392c37') }
  let(:segment) { Aws::Xray::Segment.build('test-app', trace_header) }

  describe 'serialization' do
    it 'serialized properly' do
      sub = described_class.build(trace_header, segment, remote: true, name: 'funccall_f')
      expect(sub.to_h).to match(
        name: 'funccall_f',
        id: /\A[0-9A-Fa-f]{16}\z/,
        trace_id: '1-67891233-abcdef012345678912345678',
        service: { version: 'deadbeef' },
        start_time: a_kind_of(Float),
        in_progress: true,
        parent_id: segment.id,
        type: 'subsegment',
        namespace: 'remote',
      )
      sub.finish
      expect(sub.to_h.has_key?(:in_progress)).to eq(false)
      expect(sub.to_h.has_key?(:end_time)).to eq(true)
    end
  end

  describe '#generate_trace_header' do
    it 'returns copied trace_header' do
      sub = described_class.build(trace_header, segment, remote: true, name: 'funccall_f')
      new_trace_header = sub.generate_trace_header
      expect(new_trace_header.root).to eq('1-67891233-abcdef012345678912345678')
      expect(new_trace_header.parent).to eq(sub.id)
    end
  end
end
