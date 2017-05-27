require 'aws/xray'

module Aws
  module Xray
    class Railtie < ::Rails::Railtie
      initializer 'aws-xray.set_name' do |app|
        Aws::Xray.config.name = app.class.parent_name.underscore.gsub(/(\/|_)/, '-')
      end

      initializer 'aws-xray.rack_middleware' do |app|
        app.middleware.use Aws::Xray::Rack
      end
    end
  end
end
