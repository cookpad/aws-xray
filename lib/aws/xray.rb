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

    class << self
      # @param [String] name a logical name of this tracing context.
      # @return [Object] result of given block
      def trace(name: nil, trace: Trace.generate)
        name = name || config.name || raise(MissingNameError)
        Context.with_new_context(name, trace) do
          Context.current.start_segment do |seg|
            yield seg
          end
        end
      end

      # @return [Boolean] whether tracing context is started or not.
      def started?
        Context.started?
      end

      # @return [Aws::Xray::Context]
      # @raise [Aws::Xray::NotSetError] when the current context is not yet set.
      #   Call this method after start tracing with `Aws::Xray.trace`.
      def current_context
        Context.current
      end

      # @yield [Aws::Xray::Subsegment] null subsegment
      # @return [Object] result of given block
      def start_subsegment(name:, remote:, &block)
        if started?
          current_context.start_subsegment(name: name, remote: remote, &block)
        else
          block.call(Subsegment.build_null)
        end
      end

      # @param [Symbol] id
      # @return [Object] result of given block
      def disable_trace(id, &block)
        if started?
          current_context.disable_trace(id, &block)
        else
          block.call
        end
      end

      # Overwrite under lying tracing name at once. If current context is not
      # set to current thread, do nothing.
      # @param [String] name
      # @return [Object] result of given block
      def overwrite(name:, &block)
        if started?
          current_context.overwrite(name: name, &block)
        else
          block.call
        end
      end
    end
  end
end
