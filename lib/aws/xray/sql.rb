module Aws
  module Xray
    class Sql < Struct.new(:url, :database_version)
      def self.build(url: nil, database_version: nil)
        new(url, database_version)
      end

      def to_h
        super.delete_if {|_, v| v.nil? }
      end
    end
  end
end
