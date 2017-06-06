require 'socket'

module Aws
  module Xray
    class Client
      # sock is for test.
      # Still this object can performe mutable operation `#close`,
      # freezes self to ensure everything except @sock won't be changed.
      def initialize(host: nil, port: nil, sock: nil)
        @host, @port = host.freeze, port.freeze
        @sock = sock || UDPSocket.new
        freeze
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
