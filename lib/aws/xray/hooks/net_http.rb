require 'net/http'

module Aws
  module Xray
    module Hooks
      module NetHttp
        NAME_HEADER = 'X-Aws-Xray-Name'.freeze

        def request_with_aws_xray(req, *args, &block)
          return request_without_aws_xray(req, *args) unless Context.started?
          return request_without_aws_xray(req, *args) if Context.current.disabled?(:net_http)

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
          Context.current.child_trace(remote: true, name: name) do |sub|
            propagate_trace = sub.generate_trace
            req[TRACE_HEADER] = propagate_trace.to_header_value
            sub.set_http_request(request_record)

            res = request_without_aws_xray(req, *args, &block)

            sub.set_http_response(res.code.to_i, res['Content-Length'])
            case res.code.to_i
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

            res
          end
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
