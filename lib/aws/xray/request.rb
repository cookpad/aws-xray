module Aws
  module Xray
    attrs = [:method, :url, :user_agent, :client_ip, :x_forwarded_for, :traced]
    class Request < Struct.new(*attrs)
      def self.build_from_rack_env(env)
        new(
          env['REQUEST_METHOD'], # method
          env['REQUEST_URI'], # url
          env['HTTP_USER_AGENT'], # user_agent
          env['X-Forwarded-For'], # client_ip
          !!env['X-Forwarded-For'], # x_forwarded_for
          false, # traced
        )
      end

      def self.build_from_faraday_env(env)
        new(
          env.method.to_s.upcase, # method
          env.url.to_s, # url
          env.request_headers['User-Agent'], # user_agent
          nil, # client_ip
          false, # x_forwarded_for
          false, # traced
        )
      end
    end
  end
end
