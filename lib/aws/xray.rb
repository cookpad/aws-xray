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
      # Start new tracing context and segment. If `trace` is given it start tracing context
      # following given `trace`. If `name` is omitted, it uses global
      # application name. Rescue all exceptions and record the exception to the
      # segment. Then re-raise the exception.
      #
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

      # Start subsegment if current thread has tracing context then send the
      # subsegment to X-Ray daemon. Rescue all exceptions and record the
      # exception to the subsegment. Then re-raise the exception.
      #
      # @yield [Aws::Xray::Subsegment] null subsegment
      # @return [Object] result of given block
      def start_subsegment(name:, remote:, &block)
        if started?
          current_context.start_subsegment(name: name, remote: remote, &block)
        else
          block.call(Subsegment.build_null)
        end
      end

      # Returns whether tracing context is started or not.
      # @return [Boolean]
      def started?
        Context.started?
      end

      # Return current tracing context set to current thread.
      #
      # @return [Aws::Xray::Context]
      # @raise [Aws::Xray::NotSetError] when the current context is not yet set.
      #   Call this method after start tracing with `Aws::Xray.trace`.
      def current_context
        Context.current
      end

      # Set tracing context to current thread with given context object.
      #
      # @param [Aws::Xray::Context] context copied context
      # @return [Object] result of given block
      def with_given_context(context, &block)
        Context.with_given_context(context, &block)
      end

      # Temporary disabling tracing for given id in given block.
      # CAUTION: the disabling will NOT be propagated between threads!!
      #
      # @param [Symbol] id
      # @return [Object] result of given block
      def disable_trace(id, &block)
        if started?
          current_context.disable_trace(id, &block)
        else
          block.call
        end
      end

      # Returns whether tracing is disabled with `.disable_trace` for given `id`.
      # @param [Symbol] id
      # @return [Boolean]
      def disabled?(id)
        started? && current_context.disabled?(id)
      end

      # Temporary overwrite subsegment with the name in the block. The
      # overwriting will be occured only one time. If current context is not
      # set to current thread, do nothing. CAUTION: the injection will NOT be
      # propagated between threads!!
      #
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
