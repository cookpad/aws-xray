require 'socket'
require 'aws/xray/annotation_normalizer'
require 'aws/xray/version_detector'
require 'aws/xray/error_handlers'

module Aws
  module Xray
    # thread-unsafe, suppose to be used only in initialization phase.
    class Configuration
      # @return [String] name Logical service name for this application.
      def name
        @name ||= ENV['AWS_XRAY_NAME']
      end
      attr_writer :name

      # @return [Hash] client_options For xray-agent client.
      #   - host: e.g. '127.0.0.1'
      #   - port: e.g. 2000
      def client_options
        @client_options ||=
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
      end
      attr_writer :client_options

      # @return [Array<String>]
      def excluded_paths
        @excluded_paths ||= (ENV['AWS_XRAY_EXCLUDED_PATHS'] || '').split(',')
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
        @default_annotation = AnnotationNormalizer.call(annotation)
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

      def segment_sending_error_handler
        @segment_sending_error_handler ||= DefaultErrorHandler.new($stderr)
      end
      # @param [Proc] segment_sending_error_handler Callable object
      attr_writer :segment_sending_error_handler

      # @return [Aws::Xray::Worker::Configuration]
      def worker
        @worker ||= Aws::Xray::Worker::Configuration.new
      end
      # Set given configuration and reset workers according to the given
      # configuration.
      # @param [Aws::Xray::Worker::Configuration] conf
      def worker=(conf)
        @worker = conf
        Aws::Xray::Worker.reset(conf)
        conf
      end

      # Default is 0.1%.
      # @return [Float]
      def sampling_rate
        @sampling_rate ||= Float(ENV['AWS_XRAY_SAMPLING_RATE'] || 0.001)
      end
      # @param [Float] sampling_rate
      attr_writer :sampling_rate
    end
  end
end
