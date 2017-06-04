require 'aws/xray/header_parser'
require 'securerandom'

module Aws
  module Xray
    class Trace
      class << self
        def generate(now = Time.now)
          new(root: generate_root(now))
        end

        def build_from_header_value(header_value, now = Time.now)
          h = HeaderParser.parse(header_value)
          root = h['Root'] || generate_root(now)
          new(root: root, sampled: h['Sampled'] != '0', parent: h['Parent'])
        end

        private

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

      def copy(parent:)
        self.class.new(root: @root, sampled: @sampled, parent: parent)
      end
    end
  end
end
