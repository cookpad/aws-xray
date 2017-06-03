module Aws
  module Xray
    module HeaderParser
      extend self

      # XXX: returns error when given invaild header_value
      # Header format document: http://docs.aws.amazon.com/xray/latest/devguide/xray-concepts.html#xray-concepts-tracingheader
      def parse(header_value)
        h = {}
        key = ''
        value = ''
        value_mode = false
        header_value.chars.each_with_index do |c, i|
          next if space?(c)
          if delim?(c)
            h[key] = value unless key.empty?
            key, value = '', ''
            value_mode = false
            next
          end

          if equal_mark?(c)
            value_mode = true
            next
          end

          if value_mode
            value << c
          else
            key << c
          end
        end
        h[key] = value if !key.empty? && !value.empty?
        h
      end

      def space?(c)
        c == ' '
      end

      def delim?(c)
        c == ';'
      end

      def equal_mark?(c)
        c == '='
      end
    end
  end
end
