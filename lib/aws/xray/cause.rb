module Aws
  module Xray
    class Cause
      MAX_BACKTRACE_SIZE = 10

      def initialize(stack: [], message: nil, type: nil)
        @id = SecureRandom.hex(8)
        @working_directory = Dir.pwd
        @stack = stack
        @message = message
        @type = type
      end

      def to_h(remote: false)
        truncated, stack = build_stack(@stack, @working_directory)
        {
          working_directory: @working_directory,
          paths: [],
          exceptions: [
            {
              id: @id,
              message: @message,
              type: @type,
              remote: remote,
              truncated: truncated,
              stack: stack,
            },
        ],
        }
      end

      def build_stack(stack, dir)
        truncated = [stack.size - MAX_BACKTRACE_SIZE, 0].max
        stack = stack[0..MAX_BACKTRACE_SIZE - 1].map do |s|
          file, line, method_name = s.split(':')
          {
            path: file.sub(dir, ''),
            line: line,
            label: method_name,
          }
        end
        return truncated, stack
      end
    end
  end
end
