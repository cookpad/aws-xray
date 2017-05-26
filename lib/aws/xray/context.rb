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

        def with_new_context(name, client, trace_header)
          build_current(name, client, trace_header)
          yield
        ensure
          remove_current
        end

        private

        def build_current(name, client, trace_header)
          Thread.current.thread_variable_set(VAR_NAME, Context.new(name, client, trace_header))
        end

        def remove_current
          Thread.current.thread_variable_set(VAR_NAME, nil)
        end
      end

      attr_reader :name

      def initialize(name, client, trace_header)
        @name = name
        @client = client
        @trace_header = trace_header
        @base_segment = Segment.build(@name, trace_header)
      end

      def base_trace
        res = yield @base_segment
        @client.send_segment(@base_segment)
        res
      rescue => e
        @base_segment.set_error(fault: true, e: e)
        @client.send_segment(@base_segment)
        raise e
      end

      # @param [Boolean] remote
      # @yield [Aws::Xray::SubSegment]
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
