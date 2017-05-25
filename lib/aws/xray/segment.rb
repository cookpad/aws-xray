require 'json'
require 'securerandom'
require 'aws/xray/request'
require 'aws/xray/response'

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

      # @param [Aws::Xray::Request] request
      def set_http_request(request)
        @http_request = request
      end

      # @param [Integer] status HTTP status
      # @param [Integer] length Size of HTTP response body
      def set_http_response(status, length)
        @http_response = Response.new(status, length)
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
        if @http_request
          request_hash = @http_request.to_h
          # traced is SubSegment only
          request_hash.delete(:traced)
          h[:http] = { request:  request_hash }
        end
        if @http_response
          h[:http] ||= {}
          h[:http][:response] = @http_response.to_h
        end
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
