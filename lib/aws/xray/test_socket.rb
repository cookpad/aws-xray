module Aws
  module Xray
    # For test
    #
    # @example
    #   io = Aws::Xray::TestSocket
    #   Aws::Xray.config.client_options = { sock: io }
    #   # Sending...
    #   io.rewind
    #   sent_jsons = io.read #=> Sent messages
    #   p sent_jsons.split("\n").map {|j| JSON.parse(j) }
    class TestSocket < ::StringIO
      def send(body, *)
        write(body)
      end
    end
  end
end
