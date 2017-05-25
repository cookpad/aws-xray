module Aws
  module Xray
    class Error < Struct.new(:error, :throttle, :fault, :e, :remote)
      MAX_BACKTRACE_SIZE = 10

      def to_h
        h = {
          error: error,
          throttle: throttle,
          fault: fault
        }
        if e
          h[:cause] = build_cause(e, remote)
        end
        h
      end

      private

      # TODO: Setting cause API. Downstream API's exception?
      # TODO: paths.
      def build_cause(e, remote)
        truncated, stacks = build_stack(e, Dir.pwd + '/')
        {
          working_directory: Dir.pwd,
          paths: [],
          exceptions: [
            id: SecureRandom.hex(8),
            message: e.message,
            type: e.class.to_s,
            remote: remote,
            truncated: truncated,
            skipped: 0,
            cause: nil,
            stack: stacks,
          ],
        }
      end

      def build_stack(e, dir)
        truncated = [e.backtrace.size - MAX_BACKTRACE_SIZE, 0].max
        stacks = e.backtrace[0..MAX_BACKTRACE_SIZE - 1].map do |b|
          file, line, method_name = b.split(':')
          {
            path: file.sub(dir, ''),
            line: line,
            label: method_name,
          }
        end
        return truncated, stacks
      end
    end
  end
end
