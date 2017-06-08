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
        payload = %!{"format": "json", "version": 1}\n#{segment.to_json}\n!
        sock = @sock || UDPSocket.new

        begin
          len = sock.send(payload, 0, @host, @port)
          $stderr.puts("Can not send all bytes: #{len} sent") if payload.size != len
        ensure
          sock.close
        end
      end
    end
  end
end
