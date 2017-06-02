module Aws
  module Xray
    # For specification: http://docs.aws.amazon.com/xray/latest/devguide/xray-api-segmentdocuments.html
    module AnnotationNormalizer
      extend self

      # @param [Hash] h annotation hash.
      # @return [Hash]
      def call(h)
        h.inject({}) {|init, (k, v)| init[normalize_key(k)] = normalize_value(v); init }
      end

      private

      INVALID_PATTERN = /[^A-Za-z0-9_]+/
      # - Convert keys which including '-' to '_'
      #   because it might be common pit-fall.
      # - Remove invalid chars.
      def normalize_key(k)
        k.to_s.gsub('-', '_').gsub(INVALID_PATTERN, '').to_sym
      end

      def normalize_value(v)
        case v
        when nil
          nil
        when Integer, Float
          v
        when true, false
          v
        else
          v.to_s
        end
      end
    end
  end
end
