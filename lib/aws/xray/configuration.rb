require 'socket'
require 'aws/xray/annotation_normalizer'
require 'aws/xray/version_detector'
require 'aws/xray/error_handlers'

module Aws
  module Xray
    # thread-unsafe, suppose to be used only in initialization phase.
    class Configuration
      # Freeze to force users to set default annotation with writer method.
      DEFAULT_ANNOTATION = {
        hostname: Socket.gethostname,
      }.freeze

      DEFAULT_METADATA = {
        tracing_sdk: {
          name: 'aws-xray',
          version: Aws::Xray::VERSION,
        }
      }.freeze

      def initialize
        @logger = ::Logger.new($stdout).tap {|l| l.level = Logger::INFO }
        @name = ENV['AWS_XRAY_NAME']
        @client_options =
          begin
            option = (ENV['AWS_XRAY_LOCATION'] || '').split(':')
            host = option[0]
            port = option[1]
            if (host && !host.empty?) && (port && !port.empty?)
              { host: host, port: Integer(port) }
            else
              { sock: NullSocket.new }
            end
          end
        @excluded_paths = (ENV['AWS_XRAY_EXCLUDED_PATHS'] || '').split(',')
        @version = VersionDetector.new.call
        @default_annotation = DEFAULT_ANNOTATION
        @default_metadata = DEFAULT_METADATA
        @segment_sending_error_handler = DefaultErrorHandler.new($stderr)
        @worker = Aws::Xray::Worker::Configuration.new
        @sampling_rate = Float(ENV['AWS_XRAY_SAMPLING_RATE'] || 1.0)
        @solr_hook_name = 'solr'
        @record_caller_of_http_requests = false
      end

      # @param [String] name Logical service name for this application.
      # @return [String]
      attr_accessor :name

      # @param [Hash] client_options For xray-agent client.
      #   - host: e.g. '127.0.0.1'
      #   - port: e.g. 2000
      # @return [Hash]
      attr_accessor :client_options

      # @param [Array<String>] excluded_paths
      # @return [Array<String>]
      attr_accessor :excluded_paths

      # @return [String]
      attr_reader :version
      # @param [String,Proc] version A String or callable object which returns application version.
      #   Default version detection tries to solve with `app_root/REVISION` file.
      def version=(v)
        @version = v.respond_to?(:call) ? v.call : v
      end

      # @return [Hash]
      attr_reader :default_annotation
      # @param [Hash] annotation annotation with key-value format. keys and
      #   values are automatically normalized according to X-Ray's format spec.
      def default_annotation=(annotation)
        @default_annotation = AnnotationNormalizer.call(annotation)
      end

      # @param [Hash] default_metadatametadata Default metadata.
      # @return [Hash]
      attr_accessor :default_metadata

      # @param [Proc] segment_sending_error_handler Callable object
      attr_accessor :segment_sending_error_handler

      # @return [Aws::Xray::Worker::Configuration]
      attr_reader :worker
      # Set given configuration and reset workers according to the given
      # configuration.
      # @param [Aws::Xray::Worker::Configuration] conf
      def worker=(conf)
        @worker = conf
        Aws::Xray::Worker.reset(conf)
        conf
      end

      # Default is undefined.
      # @param [Float] sampling_rate
      # @return [Float]
      attr_accessor :sampling_rate

      # @param [Logger] logger
      # @return [Logger]
      attr_accessor :logger

      # @param [String] solr_hook_name
      # @return [String]
      attr_accessor :solr_hook_name

      # @param [Boolean] record_caller_of_http_requests
      # @return [Boolean]
      attr_accessor :record_caller_of_http_requests
    end
  end
end
