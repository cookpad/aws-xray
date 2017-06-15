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
  end
end
