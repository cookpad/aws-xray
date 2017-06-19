require 'socket'

module Aws
  module Xray
    # Own the responsibility of holding destination address and sending
    # segments.
    class Client
      # sock is for test.
      def initialize(host: nil, port: nil, sock: nil)
        @host, @port = host, port
        @sock = sock
      end

      def copy
        self.class.new(host: @host ? @host.dup : nil, port: @port, sock: @sock)
      end

      # When UDPSocket#send can not send all bytes, just give up it.
      # @param [Aws::Xray::Segment] segment
      def send_segment(segment)
        Aws::Xray.config.logger.debug("#{Thread.current}: Client#send_segment started")
        payload = %!{"format": "json", "version": 1}\n#{segment.to_json}\n!

        begin
          if @sock # test env or not aws-xray is not enabled
            send_payload(payload)
            Aws::Xray.config.logger.debug("#{Thread.current}: Client#send_segment called #send_payload in the same thread")
          else # production env
            Worker.post(payload, self.copy)
            Aws::Xray.config.logger.debug("#{Thread.current}: Client#send_segment posted a job to worker")
          end
        rescue QueueIsFullError => e
          begin
            Aws::Xray.config.segment_sending_error_handler.call(e, payload, host: @host, port: @port)
          rescue Exception => e
            $stderr.puts("Error handler `#{Aws::Xray.config.segment_sending_error_handler}` raised an error: #{e}\n#{e.backtrace.join("\n")}")
          end
        end
      end

      # Will be called in other threads.
      # @param [String] payload
      def send_payload(payload)
        Aws::Xray.config.logger.debug("#{Thread.current}: Client#send_payload")
        sock = @sock || UDPSocket.new

        begin
          len = sock.send(payload, Socket::MSG_DONTWAIT, @host, @port)
          raise CanNotSendAllByteError.new(payload.size, len) if payload.size != len
          Aws::Xray.config.logger.debug("#{Thread.current}: Client#send_payload successfully sent payload, len=#{len}")
          len
        rescue SystemCallError, SocketError, CanNotSendAllByteError => e
          begin
            Aws::Xray.config.segment_sending_error_handler.call(e, payload, host: @host, port: @port)
          rescue Exception => e
            $stderr.puts("Error handler `#{Aws::Xray.config.segment_sending_error_handler}` raised an error: #{e}\n#{e.backtrace.join("\n")}")
          end
        ensure
          sock.close
        end
      end
    end
  end
end
