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

      @post_lock = ::Mutex.new
      @pid = $$
      class << self
        # @param [String] payload to send
        # @param [Aws::Xray::Client] client
        def post(payload, client)
          Aws::Xray.config.logger.debug("#{Thread.current}: Worker.post received a job")
          @post_lock.synchronize do
            refresh_if_forked
            @queue.push(Item.new(payload, client.copy))
          end
          Aws::Xray.config.logger.debug("#{Thread.current}: Worker.post pushed a job")
        rescue ThreadError => e
          raise QueueIsFullError.new(e)
        end

        # @param [Aws::Xray::Worker::Configuration] config
        def reset(config)
          @queue = Thread::SizedQueue.new(config.max_queue_size)
          @workers.each(&:kill) if defined?(@workers) && !@workers.empty?
          @workers = Array.new(config.num) { new(@queue).run }
        end

        private

        def refresh_if_forked
          if @pid != $$
            reset(Aws::Xray.config.worker)
            @pid = $$
          end
        end
      end

      def initialize(queue)
        @queue = queue
      end

      def run
        th = Thread.new(@queue) do |queue|
          loop do
            Aws::Xray.config.logger.debug("#{Thread.current}: Worker#run waits a job")
            item = queue.pop
            Aws::Xray.config.logger.debug("#{Thread.current}: Worker#run received a job")
            if item.is_a?(Item)
              item.client.send_payload(item.payload)
              Aws::Xray.config.logger.debug("#{Thread.current}: Worker#run sent a payload")
            else
              Aws::Xray.config.logger.debug("#{Thread.current}: Worker#run received invalid item, ignored it")
            end
          end
        end
        th.abort_on_exception = true
        th
      end
    end
  end
end
