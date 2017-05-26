module Aws
  module Xray
    class VersionDetector
      REVISION_PATH = 'REVISION'

      def call
        if File.exist?(REVISION_PATH)
          File.read(REVISION_PATH)
        end
      end
    end
  end
end
