require 'faraday'

module Aws
  module Xray
    class Faraday < ::Faraday::Middleware
      def initialize(app, name = nil)
        super(app)
        @name = name
      end

      def call(req_env)
        name = @name || req_env.request_headers['Host'] || "unknown-request-from-#{Context.current.name}"

        Context.current.child_trace(remote: true, name: name) do |sub|
          propagate_trace_header = sub.generate_trace_header
          req_env.request_headers[TRACE_HEADER] = propagate_trace_header.to_header_value
          sub.set_http_request(Request.build_from_faraday_env(req_env))

          @app.call(req_env).on_complete do |res_env|
            sub.set_http_response(res_env.status, res_env.response_headers['Content-Length'])
            case res_env.status
            when 499
              cause = Cause.new(stack: caller, message: 'Got 499', type: 'http_request_error')
              sub.set_error(error: true, throttle: true, cause: cause)
            when 400..498
              cause = Cause.new(stack: caller, message: 'Got 4xx', type: 'http_request_error')
              sub.set_error(error: true, cause: cause)
            when 500..599
              cause = Cause.new(stack: caller, message: 'Got 5xx', type: 'http_request_error')
              sub.set_error(fault: true, remote: true, cause: cause)
            else
              # pass
            end
          end
        end
      end
    end
  end
end
