require 'logger'

require 'aws/xray/version'
require 'aws/xray/errors'
require 'aws/xray/trace'
require 'aws/xray/client'
require 'aws/xray/context'
require 'aws/xray/worker'

require 'aws/xray/configuration'
require 'aws/xray/sockets'

require 'aws/xray/rack'

module Aws
  module Xray
    TRACE_HEADER = 'X-Amzn-Trace-Id'.freeze

    @config = Configuration.new
    class << self
      attr_reader :config
    end
    Worker.reset(Worker::Configuration.new)

    # @param [String] name a logical name of this tracing context.
    def self.trace(name: nil)
      name = name || config.name || raise(MissingNameError)
      Context.with_new_context(name, Trace.generate) do
        Context.current.base_trace do |seg|
          yield seg
        end
      end
    end

    # Overwrite under lying tracing name at once. If current context does not
    # set to current thread, do nothing.
    # @param [String] name
    def self.overwrite(name:, &block)
      if Context.started?
        Context.current.overwrite(name: name, &block)
      else
        block.call
      end
    end
  end
end
