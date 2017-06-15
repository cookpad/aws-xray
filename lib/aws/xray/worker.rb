module Aws
  module Xray
    class Worker
      class Configuration
        attr_reader :num, :max_queue_size

        def initialize(num: 10, max_queue_size: 1000)
          @num = num
          @max_queue_size = max_queue_size
        end
      end

      class Item < Struct.new(:payload, :client)
      end

      class << self
        # @param [String] payload to send
        # @param [Aws::Xray::Client] client
        def post(payload, client)
          @queue.push(Item.new(payload, client.copy))
        rescue ThreadError => e
          raise QueueIsFullError.new(e)
        end

        # @param [Aws::Xray::Worker::Configuration] config
        def reset(config)
          @queue = Thread::SizedQueue.new(config.max_queue_size)
          @workers.each(&:kill) if defined?(@workers) && !@workers.empty?
          @workers = Array.new(config.num) { new(@queue).run }
        end
        # Call `.reset` after class definetion section.
      end

      def initialize(queue)
        @queue = queue
      end

      def run
        th = Thread.new(@queue) do |queue|
          loop do
            item = queue.pop
            if item.is_a?(Item)
              item.client.send_payload(item.payload)
            else
              # TODO
            end
          end
        end
        th.abort_on_exception = true
        th
      end

      reset(Aws::Xray::Worker::Configuration.new)
    end
  end
end
