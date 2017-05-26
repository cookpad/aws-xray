require 'aws/xray/cause'

module Aws
  module Xray
    class Error < Struct.new(:error, :throttle, :fault, :e, :remote, :cause)
      MAX_BACKTRACE_SIZE = 10

      def to_h
        h = {
          error: error,
          throttle: throttle,
          fault: fault
        }
        if cause
          h[:cause] = cause.to_h(remote: remote)
        end
        # Overwrite cause because recording exception is more important.
        if e
          h[:cause] = build_cause_from_exception(e, remote)
        end
        h
      end

      private

      # TODO: Setting cause API. Downstream API's exception?
      # TODO: paths.
      def build_cause_from_exception(e, remote)
        truncated, stack = build_stack(e, Dir.pwd + '/')
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
            stack: stack,
          ],
        }
      end

      def build_stack(e, dir)
        truncated = [e.backtrace.size - MAX_BACKTRACE_SIZE, 0].max
        stack = e.backtrace[0..MAX_BACKTRACE_SIZE - 1].map do |b|
          file, line, method_name = b.split(':')
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
