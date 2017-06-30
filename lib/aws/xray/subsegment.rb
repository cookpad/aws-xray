require 'aws/xray/segment'
require 'aws/xray/sql'

module Aws
  module Xray
    # http://docs.aws.amazon.com/xray/latest/devguide/xray-api-segmentdocuments.html
    class Subsegment < Segment
      # @param [Boolean] remote
      def self.build(trace, parent_id, remote:, name:)
        new(name: name, trace: trace, parent_id: parent_id, remote: remote)
      end

      # Build a subsegment as null object.
      def self.build_null
        build(Trace.generate, SecureRandom.hex(8), remote: true, name: '')
      end

      TYPE_NAME = 'subsegment'.freeze

      def initialize(name:, trace:, parent_id:, remote:)
        super(name: name, trace_id: trace.root, parent_id: parent_id)
        @trace = trace
        @remote = !!remote
        @sql = nil
      end

      # Set traced=false if the downstream call is not traced app.
      # e.g. Third-party Web API call.
      # http://docs.aws.amazon.com/xray/latest/devguide/xray-api-segmentdocuments.html
      def set_http_request(env, traced: false)
        super(env)
        @http_request.traced = traced
      end

      # @param [Aws::Xray::Sql] sql
      def set_sql(sql)
        @sql = sql
      end

      def to_h
        h = super
        # x_forwarded_for is Segment only.
        if h[:http] && h[:http][:request]
          h[:http][:request].delete(:x_forwarded_for)
          h[:http][:request][:traced] = @http_request.traced
        end
        h[:type] = TYPE_NAME
        h[:namespace] = 'remote' if @remote
        h[:sql] = @sql.to_h if @sql
        h
      end

      def generate_trace
        @trace.copy(parent: @id)
      end
    end
  end
end
