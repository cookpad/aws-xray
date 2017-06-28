require 'aws/xray/segment'
require 'aws/xray/subsegment'

module Aws
  module Xray
    class Context
      VAR_NAME = :_aws_xray_context_

      class << self
        # @return [Aws::Xray::Context]
        def current
          Thread.current.thread_variable_get(VAR_NAME) || raise(NotSetError)
        end

        # @param [Aws::Xray::Context] context
        def with_given_context(context)
          Thread.current.thread_variable_set(VAR_NAME, context)
          yield
        ensure
          remove_current
        end

        # @return [Boolean]
        def started?
          !!Thread.current.thread_variable_get(VAR_NAME)
        end

        # @param [String] name logical name of this tracing context.
        # @param [Aws::Xray::Trace] trace newly generated trace or created with
        #   HTTP request header.
        # @yield [Aws::Xray::Context] newly created context.
        def with_new_context(name, trace)
          build_current(name, trace)
          yield
        ensure
          remove_current
        end

        private

        def build_current(name, trace)
          Thread.current.thread_variable_set(VAR_NAME, Context.new(name, trace))
        end

        def remove_current
          Thread.current.thread_variable_set(VAR_NAME, nil)
        end
      end

      attr_reader :name

      def initialize(name, trace, base_segment_id = nil)
        raise 'name is required' unless name
        @name = name
        @trace = trace
        @base_segment_id = base_segment_id
        @disabled_ids = []
        @subsegment_name = nil
      end

      # Curretly context object is thread safe, so copying is not necessary,
      # but in case we need this, offer copy interface for multi threaded
      # environment.
      #
      # Trace should be imutable and thread-safe.
      #
      # See README for example.
      def copy
        self.class.new(@name.dup, @trace.copy, @base_segment_id ? @base_segment_id.dup : nil)
      end

      # Rescue all exceptions and record the exception to the segment.
      # Then re-raise the exception.
      #
      # @yield [Aws::Xray::Segment]
      # @return [Object] A value which given block returns.
      def start_segment
        base_segment = Segment.build(@name, @trace)
        @base_segment_id = base_segment.id

        begin
          yield base_segment
        rescue Exception => e
          base_segment.set_error(fault: true, e: e)
          raise e
        ensure
          base_segment.finish unless base_segment.finished?
          Client.send_segment(base_segment) if @trace.sampled?
        end
      end
      alias_method :base_trace, :start_segment

      # @param [Boolean] remote
      # @param [String] name Arbitrary name of the sub segment. e.g. "funccall_f".
      # @yield [Aws::Xray::Subsegment]
      # @return [Object] A value which given block returns.
      def start_subsegment(remote:, name:)
        raise SegmentDidNotStartError unless @base_segment_id
        sub = Subsegment.build(@trace, @base_segment_id, remote: remote, name: overwrite_name(name))

        begin
          yield sub
        rescue Exception => e
          sub.set_error(fault: true, e: e)
          raise e
        ensure
          sub.finish unless sub.finished?
          Client.send_segment(sub) if @trace.sampled?
        end
      end
      alias_method :child_trace, :start_subsegment

      # Temporary disabling tracing for given id in given block.
      # CAUTION: the disabling will NOT be propagated between threads!!
      #
      # @param [Symbol] id must be unique between tracing methods.
      def disable_trace(id)
        @disabled_ids << id

        begin
          yield
        ensure
          @disabled_ids.delete(id)
        end
      end

      def disabled?(id)
        @disabled_ids.include?(id)
      end

      # CAUTION: the injection will NOT be propagated between threads!!
      #
      # Temporary overwrite subsegment with the name in the block. The
      # overwriting will be occured only one time.
      #
      # @param [String] name
      def overwrite(name:)
        return yield if @subsegment_name

        @subsegment_name = name.to_s

        begin
          yield
        ensure
          @subsegment_name = nil
        end
      end

      private

      def overwrite_name(name)
        return name unless @subsegment_name

        name = @subsegment_name
        @subsegment_name = nil
        name
      end
    end
  end
end
