require 'aws/xray/version'
require 'aws/xray/errors'
require 'aws/xray/rack'
require 'aws/xray/faraday'
require 'aws/xray/configuration'
require 'aws/xray/sockets'

module Aws
  module Xray
    TRACE_HEADER = 'X-Amzn-Trace-Id'.freeze

    @config = Configuration.new
    class << self
      attr_reader :config
    end

    # @param [String] name a logical name of this tracing context.
    def self.trace(name: nil)
      name = name || config.name || raise(MissingNameError)
      client = Client.new(Aws::Xray.config.client_options)
      Context.with_new_context(name, client, Trace.generate) do
        Context.current.base_trace do |seg|
          yield seg
        end
      end
    end
  end
end
