require 'json'
require 'securerandom'

module Aws
  module Xray
    # http://docs.aws.amazon.com/xray/latest/devguide/xray-api-segmentdocuments.html
    class Segment
      class << self
        def build(name, trace_header)
          new(name: name, trace_id: trace_header.root, parent_id: trace_header.parent)
        end
      end

      attr_reader :name, :id, :trace_id, :parent_id

      # TODO: securerandom?
      def initialize(name:, trace_id:, parent_id: nil)
        @name = name
        @id = SecureRandom.hex(8)
        @trace_id = trace_id
        @parent_id = parent_id
        start
        @end_time = nil
        @http_request = nil
        @http_response = nil
        @error = nil
      end

      # @param [Hash] env A Rack env
      def set_http_request(env)
      end

      # @param [Array] res A Rack response
      def set_http_response(res)
      end

      def set_error(e)
        # TODO: Set error object
      end

      def finish(now = Time.now)
        @end_time = now.to_f
      end

      def to_json
        to_h.to_json
      end

      def to_h
        h = {
          name: @name,
          id: @id,
          trace_id: @trace_id,
          start_time: @start_time,
        }
        if @end_time.nil?
          h[:in_progress] = true
        else
          h[:end_time] = @end_time
        end
        h[:parent_id] = @parent_id if @parent_id
        h
      end

      private

      def start(now = Time.now)
        @start_time = now.to_f
      end
    end
  end
end
