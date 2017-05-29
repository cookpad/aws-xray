require 'socket'
require 'aws/xray/annotation_validator'

module Aws
  module Xray
    # thread-unsafe, suppose to be used only in initialization phase.
    class Configuration
      option = ENV['AWS_XRAY_LOCATION']
      DEFAULT_HOST = option ? option.split(':').first : 'localhost'
      DEFAULT_PORT = option ? Integer(option.split(':').last) : 2000

      name_option = ENV['AWS_XRAY_NAME']
      DEFAULT_NAME = name_option ? name_option : nil

      path_option = ENV['AWS_XRAY_EXCLUDED_PATHS']
      DEFAULT_EXCLUDED_PATHS = path_option ? path_option.split(',') : []

      # @return [String] name Logical service name for this application.
      def name
        @name ||= DEFAULT_NAME
      end
      attr_writer :name

      # @return [Hash] client_options For xray-agent client.
      #   - host: e.g. '127.0.0.1'
      #   - port: e.g. 2000
      #   - sock: test purpose.
      def client_options
        @client_options ||= { host: DEFAULT_HOST, port: DEFAULT_PORT }
      end
      attr_writer :client_options

      # @return [Array<String>]
      def excluded_paths
        @excluded_paths ||= DEFAULT_EXCLUDED_PATHS
      end
      attr_writer :excluded_paths

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
