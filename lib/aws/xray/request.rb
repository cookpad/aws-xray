module Aws
  module Xray
    attrs = [:method, :url, :user_agent, :client_ip, :x_forwarded_for, :traced]
    class Request < Struct.new(*attrs)
      class << self
        def build(method:, url:, user_agent: nil, client_ip: nil, x_forwarded_for: nil, traced: false)
          new(method, url, user_agent, client_ip, x_forwarded_for, traced)
        end

        def build_from_rack_env(env)
          build(
            method: env['REQUEST_METHOD'],
            url: env['REQUEST_URI'],
            user_agent: env['HTTP_USER_AGENT'],
            client_ip: env['X-Forwarded-For'],
            x_forwarded_for: !!env['X-Forwarded-For'],
            traced: false,
          )
        end

        def build_from_faraday_env(env)
          build(
            method: env.method.to_s.upcase,
            url: env.url.to_s,
            user_agent: env.request_headers['User-Agent'],
            client_ip: nil,
            x_forwarded_for: false,
            traced: false,
          )
        end
      end
    end
  end
end
