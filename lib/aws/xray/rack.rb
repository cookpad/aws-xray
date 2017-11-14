module Aws
  module Xray
    class Rack
      TRACE_ENV = 'HTTP_X_AMZN_TRACE_ID'.freeze
      ORIGINAL_TRACE_ENV = 'HTTP_X_AMZN_TRACE_ID_ORIGINAL'.freeze

      # @param [Array<String,Regexp>] excluded_paths for health-check endpoints etc...
      def initialize(app, excluded_paths: [])
        @app = app
        @name = Aws::Xray.config.name || raise(MissingNameError)
        @excluded_paths = excluded_paths + Aws::Xray.config.excluded_paths
      end

      def call(env)
        if excluded_path?(env['PATH_INFO'])
          @app.call(env)
        else
          call_with_tracing(env)
        end
      end

      private

      def call_with_tracing(env)
        trace = build_trace(env[TRACE_ENV])
        env[ORIGINAL_TRACE_ENV] = env[TRACE_ENV] if env[TRACE_ENV] # just for the record
        env[TRACE_ENV] = trace.to_header_value
        record_context!(trace)

        Aws::Xray.trace(name: @name, trace: trace) do |seg|
          seg.set_http_request(Request.build_from_rack_env(env))
          status, headers, body = @app.call(env)
          length = headers['Content-Length'] || 0
          seg.set_http_response_with_error(status, length, remote: false)
          headers[TRACE_HEADER] = trace.to_header_value
          [status, headers, body]
        end
      end

      def build_trace(header_value)
        if header_value
          Trace.build_from_header_value(header_value)
        else
          Trace.generate
        end
      end

      def excluded_path?(path)
        !!@excluded_paths.find {|p| p === path }
      end

      def record_context!(trace)
        ::Raven.tags_context(xray_sampled: trace.sampled? ? '1' : '0') if defined?(::Raven)
      rescue => e
        Aws::Xray.config.logger.error("#{e.message}\n#{e.backtrace.join("\n")}")
        # Ignore the error
      end
    end
  end
end
