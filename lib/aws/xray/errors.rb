module Aws
  module Xray
    # Bacause we already had another `Error` class for domain object.
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

    class MissingNameError < BaseError
      def initialize
        super("`name` is empty. Configure this with `Aws::Xray.config.name = 'my-app'`.")
      end
    end

    class CanNotSendAllByteError < BaseError
      def initialize(payload_len, sent_len)
        super("Can not send all bytes: expected #{payload_len} but #{sent_len} sent")
      end
    end

    class QueueIsFullError < BaseError
      attr_reader :error

      def initialize(error)
        @error = error
        super('The queue exceeds max size')
      end
    end
  end
end
