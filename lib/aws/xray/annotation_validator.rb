module Aws
  module Xray
    module AnnotationValidator
      extend self

      # @param [Hash] h annotation hash.
      # @raise RuntimeError
      def call(h)
        invalid_keys = h.keys.reject {|k| k.to_s.match(/\A[A-Za-z0-9_]+\z/) }
        raise 'Keys must be alphanumeric and underscore string' unless invalid_keys.empty?
        invalid_values = h.values.reject {|v| v.is_a?(String) || v.is_a?(Integer) || (v == true || v == false) }
        raise 'Values must be one of String or Integer or Boolean values' unless invalid_values.empty?
      end
    end
  end
end
