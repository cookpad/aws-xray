module Aws
  module Xray
    module CallerBuilder
      extend self

      MAX_BACKTRACE_SIZE = 100

      # Build caller stack trace data.
      # @return [Hash] for metadata
      def call
        dir = (Dir.pwd + '/') rescue '/'
        stack = caller

        truncated = [stack.size - MAX_BACKTRACE_SIZE, 0].max
        stack = stack[0..MAX_BACKTRACE_SIZE - 1].map do |s|
          file, line, method_name = s.split(':')
          {
            path: file.sub(dir, ''),
            line: line,
            label: method_name,
          }
        end

        {
          caller: {
            stack: stack,
            truncated: truncated,
          }
        }
      end
    end
  end
end
