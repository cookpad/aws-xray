require 'socket'
require 'aws/xray/annotation_validator'

module Aws
  module Xray
    # thread-unsafe, suppose to be used only in initialization phase.
    class Configuration
      # @return [String] name Logical service name for this application.
      attr_accessor :name

      # @return [Hash] client_options For xray-agent client.
      #   - host: e.g. '127.0.0.1'
      #   - port: e.g. 2000
      #   - sock: test purpose.
      def client_options
        @client_options ||= { host: '127.0.0.1', port: 2000 }
      end
      attr_writer :client_options

      # @return [String]
      def version
        @version ||= VersionDetector.new.call
      end
      # @param [String,Proc] version A String or callable object which returns application version.
      #   Default version detection tries to solve with `app_root/REVISION` file.
      def version=(v)
        @version = v.respond_to?(:call) ? v.call : v
      end

      DEFAULT_ANNOTATION = {
        hostname: Socket.gethostname,
      }.freeze
      # @return [Hash] default annotation with key-value format.
      def default_annotation
        @default_annotation ||= DEFAULT_ANNOTATION
      end
      # @param [Hash] h default annotation Hash.
      def default_annotation=(annotation)
        AnnotationValidator.call(annotation)
        @default_annotation = annotation
      end

      DEFAULT_METADATA = {
        tracing_sdk: {
          name: 'aws-xray',
          version: Aws::Xray::VERSION,
        }
      }.freeze
      # @return [Hash] Default metadata.
      def default_metadata
        @default_metadata ||= DEFAULT_METADATA
      end
      # @param [Hash] metadata Default metadata.
      attr_writer :default_metadata
    end
  end
end
