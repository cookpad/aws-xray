module Aws
  module Xray
    class DefaultErrorHandler
      # @param [IO] io
      def initialize(io)
        @io = io
      end

      # @param [Exception] error
      # @param [String] payload
      # @param [String,nil] host
      # @param [Integer,nil] port
      def call(error, payload, host:, port:)
        @io.puts(<<-EOS)
Failed to send a segment to #{host}:#{port}:
Segment:
#{payload}
Error: #{error}
#{error.backtrace.join("\n")}
        EOS
      end
    end

    # Must be configured sentry-raven or sentry-ruby gem.
    class ErrorHandlerWithSentry
      class MissingSentryError < StandardError; end

      def initialize
        if !defined?(::Sentry) && !defined?(::Raven)
          raise MissingSentryError.new('Must be installed sentry-raven or sentry-ruby gem')
        end
      end

      ERROR_LEVEL = 'warning'.freeze

      def call(error, payload, host:, port:)
        if defined?(::Raven)
          ::Raven.capture_exception(
            error,
            level: ERROR_LEVEL,
            extra: { 'payload' => payload, 'payload_raw' => payload.unpack('H*').first }
          )

          return
        end

        ::Sentry.capture_exception(
          error,
          level: ERROR_LEVEL,
          extra: { 'payload' => payload, 'payload_raw' => payload.unpack('H*').first }
        )
      end
    end
  end
end
