require 'json'
require 'securerandom'
require 'aws/xray/request'
require 'aws/xray/response'
require 'aws/xray/error'
require 'aws/xray/annotation_normalizer'

module Aws
  module Xray
    # http://docs.aws.amazon.com/xray/latest/devguide/xray-api-segmentdocuments.html
    class Segment
      class << self
        def build(name, trace)
          new(name: name, trace_id: trace.root, parent_id: trace.parent)
        end
      end

      attr_reader :name, :id, :trace_id, :parent_id

      # TODO: securerandom?
      def initialize(name:, trace_id:, parent_id: nil)
        @name = name
        @id = SecureRandom.hex(8)
        @trace_id = trace_id
        @parent_id = parent_id
        @version = Aws::Xray.config.version
        start
        @end_time = nil
        @http_request = nil
        @http_response = nil
        @error = nil
        @annotation = Aws::Xray.config.default_annotation
        @metadata = Aws::Xray.config.default_metadata
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

      # @param [Boolean] error Indicating that a client error occurred (response status code was 4XX Client Error).
      # @param [Boolean] throttle Indicating that a request was throttled (response status code was 429 Too Many Requests).
      # @param [Boolean] fault Indicating that a server error occurred (response status code was 5XX Server Error).
      # @param [Exception] e An Exception object
      def set_error(error: false, throttle: false, fault: false, e: nil, remote: false, cause: nil)
        @error = Error.new(error, throttle, fault, e, remote, cause)
      end

      # @param [Hash] annotation Keys must consist of only alphabets and underscore.
      #   Values must be one of String or Integer or Boolean values.
      def set_annotation(annotation)
        @annotation = @annotation.merge(AnnotationNormalizer.call(annotation))
      end

      # @param [Hash] metadata
      def set_metadata(metadata)
        @metadata = @metadata.merge(metadata)
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
          annotations: @annotation,
          metadata: @metadata,
        }
        if @version
          h[:service] = { version: @version }
        end
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
        if @error
          h.merge!(@error.to_h)
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
