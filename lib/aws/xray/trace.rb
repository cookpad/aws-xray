require 'aws/xray/header_parser'
require 'securerandom'

module Aws
  module Xray
    # Imutable
    class Trace
      class << self
        def generate(now = Time.now)
          new(root: generate_root(now))
        end

        def build_from_header_value(header_value, now = Time.now)
          h = HeaderParser.parse(header_value)
          root = h['Root'] || generate_root(now)
          new(root: root, sampled: decide_sampling(h['Sampled']), parent: h['Parent'])
        end

        private

        # Decide sample this request or not. At first, check parent's sampled
        # and follow the value if it exists. Then decide sampled or not
        # according to configured sampling_rate.
        # @param [String,nil] value
        # @return [Bloolean]
        def decide_sampling(value)
          case value
          when '0'
            false
          when '1'
            true
          else
            rand < Aws::Xray.config.sampling_rate
          end
        end

        def generate_root(now)
          "1-#{now.to_i.to_s(16)}-#{SecureRandom.hex(12)}"
        end
      end

      attr_reader :root, :parent

      def initialize(root:, sampled: true, parent: nil)
        @root = root
        @sampled = sampled
        @parent = parent
      end

      def to_header_value
        v = "Root=#{@root};"
        sampled? ? v << 'Sampled=1' : v << 'Sampled=0'
        v << ";Parent=#{@parent}" if has_parent?
        v
      end

      def sampled?
        @sampled
      end

      def has_parent?
        !!@parent
      end

      def copy(parent: @parent)
        self.class.new(root: @root.dup, sampled: @sampled, parent: parent ? parent.dup : nil)
      end
    end
  end
end
