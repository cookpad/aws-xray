require 'aws/xray/trace_header'
require 'aws/xray/client'
require 'aws/xray/context'
require 'aws/xray/version_detector'

module Aws
  module Xray
    class Rack
      TRACE_ENV = 'HTTP_X_AMZN_TRACE_ID'.freeze

      class MissingNameError < ::StandardError
        def initialize
          super("`name` is empty. Configure this with `Aws::Xray.config.name = 'my-app'`.")
        end
      end

      # TODO: excluded_paths, included_paths
      #
      # @param [String] name Logical service name.
      # @param  [Hash] client_options For xray-agent client.
      #   - host: e.g. '127.0.0.1'
      #   - port: e.g. 2000
      #   - sock: test purpose.
      def initialize(app, name: nil, client_options: {})
        @app = app
        @name = name || Aws::Xray.config.name || raise(MissingNameError)
        @client = Client.new(Aws::Xray.config.client_options.merge(client_options))
      end

      def call(env)
        header_value = env[TRACE_ENV]
        trace_header = if header_value
                         TraceHeader.build_from_header_value(header_value)
                       else
                         TraceHeader.generate
                       end

        Context.with_new_context(@name, @client, trace_header) do
          Context.current.base_trace do |seg|
            seg.set_http_request(Request.build_from_rack_env(env))
            status, headers, body = @app.call(env)
            seg.set_http_response(status, headers['Content-Length'])
            headers[TRACE_HEADER] = trace_header.to_header_value
            [status, headers, body]
          end
        end
      end
    end
  end
end
