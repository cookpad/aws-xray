require 'aws/xray'

module Aws
  module Xray
    class Railtie < ::Rails::Railtie
      initializer 'aws-xray.rack_middleware' do |app|
        app.middleware.use Aws::Xray::Rack
      end
    end
  end
end
