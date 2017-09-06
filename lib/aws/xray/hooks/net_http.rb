require 'aws/xray'
require 'net/http'

module Aws
  module Xray
    module Hooks
      module NetHttp
        NAME_HEADER = 'X-Aws-Xray-Name'.freeze

        def request_with_aws_xray(req, *args, &block)
          return request_without_aws_xray(req, *args, &block) unless Context.started?
          return request_without_aws_xray(req, *args, &block) if Context.current.disabled?(:net_http)

          uri = URI('')
          uri.scheme = use_ssl? ? 'https' : 'http'
          uri.host = address
          uri.port = port
          uri.path = URI(req.path).path
          request_record = Request.build(
            method: req.method,
            url: uri.to_s,
            user_agent: req['User-Agent'],
          )
          name = req[NAME_HEADER] || req['Host'] || address
          Context.current.start_subsegment(remote: true, name: name) do |sub|
            if pass_trace_header?(address)
              propagate_trace = sub.generate_trace
              req[TRACE_HEADER] = propagate_trace.to_header_value
            end
            sub.set_http_request(request_record)

            # Don't record twice if down-stream caller calls Net::HTTP#request again.
            res = Context.current.disable_trace(:net_http) { request_without_aws_xray(req, *args, &block) }

            sub.set_http_response_with_error(res.code.to_i, res['Content-Length'], remote: true)
            sub.add_metadata(CallerBuilder.call) if Aws::Xray.config.record_caller_of_http_requests
            res
          end
        end

        private

        def pass_trace_header?(host)
          !!Aws::Xray.config.trace_header_whitelist_hosts.find {|h| h === host }
        end
      end
    end
  end
end

class Net::HTTP
  include Aws::Xray::Hooks::NetHttp

  alias request_without_aws_xray request
  alias request request_with_aws_xray
end
