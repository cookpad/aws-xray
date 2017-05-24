require 'aws/xray/version'
require 'aws/xray/rack'
require 'aws/xray/faraday'

module Aws
  module Xray
    TRACE_HEADER = 'X-Amzn-Trace-Id'.freeze
  end
end
