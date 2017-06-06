require 'aws/xray/segment'
require 'aws/xray/sub_segment'

module Aws
  module Xray
    class Context
      VAR_NAME = :_aws_xray_context_

      class BaseError < ::StandardError; end

      class NotSetError < BaseError
        def initialize
          super('Context is not set for this thread')
        end
      end

      class SegmentDidNotStartError < BaseError
        def initialize
          super('Segment did not start yet')
        end
      end

      class << self
        # @return [Aws::Xray::Context]
        def current
          Thread.current.thread_variable_get(VAR_NAME) || raise(NotSetError)
        end

        # @return [Boolean]
        def started?
          !!Thread.current.thread_variable_get(VAR_NAME)
        end

        # @param [String] name logical name of this tracing context.
        # @param [Aws::Xray::Client] client Require this parameter because the
        #   socket inside client can live longer than this context. For example
        #   the life-cycle of context is HTTP request based but the socket can
        #   live over HTTP requests cycle, it is opened when application starts
        #   then is closed when application exits.
        # @param [Aws::Xray::Trace] trace newly generated trace or created with
        #   HTTP request header.
        # @yield [Aws::Xray::Context] newly created context.
        def with_new_context(name, client, trace)
          build_current(name, client, trace)
          yield
        ensure
          remove_current
        end

        private

        def build_current(name, client, trace)
          Thread.current.thread_variable_set(VAR_NAME, Context.new(name, client, trace))
        end

        def remove_current
          Thread.current.thread_variable_set(VAR_NAME, nil)
        end
      end

      attr_reader :name

      # client and trace are frozen by default.
      def initialize(name, client, trace, base_segment_id = nil)
        @name = name.freeze
        @client = client
        @trace = trace
        @base_segment_id = base_segment_id
      end

      # Curretly context object is thread safe, so copying is not necessary,
      # but in case we need this, offer copy interface for multi threaded
      # environment.
      #
      # client and trace should be imutable and thread-safe.
      def copy
        self.class.new(@name, @client, @trace, @base_segment_id)
      end

      # Rescue standard errors and record the error to the segment.
      # Then re-raise the error.
      #
      # @yield [Aws::Xray::Segment]
      # @return [Object] A value which given block returns.
      def base_trace
        base_segment = Segment.build(@name, @trace)
        @base_segment_id = base_segment.id.freeze

        begin
          yield base_segment
        rescue => e
          base_segment.set_error(fault: true, e: e)
          raise e
        ensure
          base_segment.finish
          @client.send_segment(base_segment)
        end
      end

      # Rescue standard errors and record the error to the sub segment.
      # Then re-raise the error.
      #
      # @param [Boolean] remote
      # @param [String] name Arbitrary name of the sub segment. e.g. "funccall_f".
      # @yield [Aws::Xray::SubSegment]
      # @return [Object] A value which given block returns.
      def child_trace(remote:, name:)
        raise SegmentDidNotStartError unless @base_segment_id
        sub = SubSegment.build(@trace, @base_segment_id, remote: remote, name: name)

        begin
          yield sub
        rescue => e
          sub.set_error(fault: true, e: e)
          raise e
        ensure
          sub.finish
          @client.send_segment(sub)
        end
      end
    end
  end
end
