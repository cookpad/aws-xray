require 'aws/xray/header_parser'
require 'securerandom'

module Aws
  module Xray
    # Imutable
    class Trace
      class << self
        def generate(now = Time.now)
          new(root: generate_root(now), sampled: decide_sampling(nil))
        end

        def build_from_header_value(header_value, now = Time.now)
          h = HeaderParser.parse(header_value)
          root = h['Root'] || generate_root(now)
          rest = h.dup.tap {|e| %w[Root Sampled Parent].each {|k| e.delete(k) } }
          new(root: root, sampled: decide_sampling(h['Sampled']), parent: h['Parent'], rest: rest)
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

      def initialize(root:, sampled:, parent: nil, rest: {})
        @root = root
        @sampled = sampled
        @parent = parent
        @rest = rest
      end

      def to_header_value
        to_header_hash.map {|k, v| "#{k}=#{v}" }.join(';')
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

      private

      def to_header_hash
        h = {'Root' => @root, 'Sampled' => sampled? ? '1' : '0' }
        h['Parent'] = @parent if has_parent?
        h.merge!(@rest)
        h
      end
    end
  end
end
