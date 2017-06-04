require 'aws/xray/trace'
require 'aws/xray/client'
require 'aws/xray/context'
require 'aws/xray/version_detector'

module Aws
  module Xray
    class Rack
      TRACE_ENV = 'HTTP_X_AMZN_TRACE_ID'.freeze
      ORIGINAL_TRACE_ENV = 'HTTP_X_AMZN_TRACE_ID_ORIGINAL'.freeze

      # @param  [Hash] client_options For xray-agent client.
      #   - host: e.g. '127.0.0.1'
      #   - port: e.g. 2000
      #   - sock: test purpose.
      # @param [Array<String>] excluded_paths for health-check endpoints etc...
      def initialize(app, client_options: {}, excluded_paths: [])
        @app = app
        @name = Aws::Xray.config.name || raise(MissingNameError)
        @client = Client.new(Aws::Xray.config.client_options.merge(client_options))
        @excluded_paths = excluded_paths + Aws::Xray.config.excluded_paths
      end

      def call(env)
        if @excluded_paths.include?(env['PATH_INFO'])
          @app.call(env)
        else
          call_with_tracing(env)
        end
      end

      private

      def call_with_tracing(env)
        trace = build_trace(env[TRACE_ENV])
        env[ORIGINAL_TRACE_ENV] = env[TRACE_ENV] # just for the record
        env[TRACE_ENV] = trace.to_header_value

        Context.with_new_context(@name, @client, trace) do
          Context.current.base_trace do |seg|
            seg.set_http_request(Request.build_from_rack_env(env))
            status, headers, body = @app.call(env)
            seg.set_http_response(status, headers['Content-Length'])
            headers[TRACE_HEADER] = trace.to_header_value
            [status, headers, body]
          end
        end
      end

      def build_trace(header_value)
        if header_value
          Trace.build_from_header_value(header_value)
        else
          Trace.generate
        end
      end
    end
  end
end
