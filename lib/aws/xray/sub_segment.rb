require 'aws/xray/segment'

module Aws
  module Xray
    # http://docs.aws.amazon.com/xray/latest/devguide/xray-api-segmentdocuments.html
    class SubSegment < Segment
      # @param [Boolean] remote
      def self.build(trace_header, parent, remote:, name:)
        new(name: name, trace_id: trace_header.root, parent_id: parent.id, remote: remote)
      end

      TYPE_NAME = 'subsegment'.freeze

      def initialize(name:, trace_id:, parent_id:, remote:)
        super(name: name, trace_id: trace_id, parent_id: parent_id)
        @remote = !!remote
      end

      def to_h
        h = super
        h[:type] = TYPE_NAME
        h[:namespace] = 'remote' if @remote
        h
      end
    end
  end
end
