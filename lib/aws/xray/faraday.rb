require 'faraday'

module Aws
  module Xray
    class Faraday < ::Faraday::Middleware
      def initialize(app, name = nil)
        super(app)
        @name = name
      end

      # XXX: use host header?
      def call(req_env)
        name = @name || req_env.request_headers['Host'] || "unknown-request-from-#{Context.current.name}"

        Context.current.child_trace(remote: true, name: name) do |sub|
          propagate_trace_header = sub.generate_trace_header
          req_env.request_headers[TRACE_HEADER] = propagate_trace_header.to_header_value
          sub.set_http_request(req_env)

          @app.call(req_env).on_complete do |res_env|
            sub.set_http_response(res_env)
          end
        end
      end
    end
  end
end
