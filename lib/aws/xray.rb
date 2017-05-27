require 'aws/xray/version'
require 'aws/xray/rack'
require 'aws/xray/faraday'
require 'aws/xray/configuration'

module Aws
  module Xray
    TRACE_HEADER = 'X-Amzn-Trace-Id'.freeze

    @config = Configuration.new
    class << self
      attr_reader :config
    end
  end
end

require 'aws/xray/rails' if defined?(Rails)
