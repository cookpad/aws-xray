require 'socket'

module Aws
  module Xray
    class Client
      # sock is for test
      #
      # XXX: keep options for implmenting copying later.
      def initialize(host: nil, port: nil, sock: nil)
        @host, @port = host, port
        @sock = sock || UDPSocket.new
      end

      # @param [Aws::Xray::Segment] segment
      def send_segment(segment)
        payload = %!{"format": "json", "version": 1}\n#{segment.to_json}\n!
        len = @sock.send(payload, 0, @host, @port)
        # TODO: retry
        if payload.size != len
          $stderr.puts("Can not send all bytes: #{len} sent")
        end
      end

      def close
        @sock.close
      end
    end
  end
end
