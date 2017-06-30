require 'faraday'
require 'aws/xray'

module Aws
  module Xray
    class Faraday < ::Faraday::Middleware
      # @param [Object] app Faraday app.
      # @param [String] name Logical service name for downstream API.
      def initialize(app, name = nil)
        raise ArgumentError.new("name must be a String but given a #{name.class}") if name && !name.is_a?(String)
        super(app)
        @name = name
      end

      def call(req_env)
        return @app.call(req_env) unless Context.started?

        name = @name || req_env.request_headers['Host'] || "unknown-request-from-#{Context.current.name}"

        Context.current.start_subsegment(remote: true, name: name) do |sub|
          propagate_trace = sub.generate_trace
          req_env.request_headers[TRACE_HEADER] = propagate_trace.to_header_value
          sub.set_http_request(Request.build_from_faraday_env(req_env))

          res = Context.current.disable_trace(:net_http) { @app.call(req_env) }
          res.on_complete do |res_env|
            sub.set_http_response_with_error(res_env.status, res_env.response_headers['Content-Length'], remote: true)
            sub.add_metadata(CallerBuilder.call) if Aws::Xray.config.record_caller_of_http_requests
          end
        end
      end
    end
  end
end
