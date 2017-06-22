require 'aws/xray'
require 'rsolr'

module Aws
  module Xray
    module Hooks
      module Rsolr
        def send_and_receive_with_aws_xray(*args, &block)
          Aws::Xray.overwrite(name: Aws::Xray.config.solr_hook_name) do
            send_and_receive_without_aws_xray(*args, &block)
          end
        end
      end
    end
  end
end

class RSolr::Client
  include(Aws::Xray::Hooks::Rsolr)

  alias send_and_receive_without_aws_xray send_and_receive
  alias send_and_receive send_and_receive_with_aws_xray
end
