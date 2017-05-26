require 'aws/xray/segment'
require 'aws/xray/sub_segment'

module Aws
  module Xray
    class Context
      class << self
        VAR_NAME = :_aws_xray_context_

        class NotSetError < ::StandardError
          def initialize
            super('Context is not set for this thread')
          end
        end

        def current
          Thread.current.thread_variable_get(VAR_NAME) || raise(NotSetError)
        end

        def with_new_context(name, client, trace_header, version = nil)
          build_current(name, client, trace_header, version)
          yield
        ensure
          remove_current
        end

        private

        def build_current(name, client, trace_header, version)
          Thread.current.thread_variable_set(VAR_NAME, Context.new(name, client, trace_header, version))
        end

        def remove_current
          Thread.current.thread_variable_set(VAR_NAME, nil)
        end
      end

      attr_reader :name

      def initialize(name, client, trace_header, version = nil)
        @name = name
        @client = client
        @trace_header = trace_header
        @base_segment = Segment.build(@name, trace_header, version)
      end

      # Rescue standard errors and record the error to the segment.
      # Then re-raise the error.
      #
      # @yield [Aws::Xray::Segment]
      # @return [Object] A value which given block returns.
      def base_trace
        res = yield @base_segment
        @client.send_segment(@base_segment)
        res
      rescue => e
        @base_segment.set_error(fault: true, e: e)
        @client.send_segment(@base_segment)
        raise e
      end

      # Rescue standard errors and record the error to the sub segment.
      # Then re-raise the error.
      #
      # @param [Boolean] remote
      # @param [String] name Arbitrary name of the sub segment. e.g. "funccall_f".
      # @yield [Aws::Xray::SubSegment]
      # @return [Object] A value which given block returns.
      def child_trace(remote:, name:)
        sub = SubSegment.build(@trace_header, @base_segment, remote: remote, name: name)
        res = yield sub
        @client.send_segment(sub)
        res
      rescue => e
        sub.set_error(fault: true, e: e)
        @client.send_segment(sub)
        raise e
      end
    end
  end
end
