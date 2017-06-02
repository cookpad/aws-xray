require 'aws/xray'

module Aws
  module Xray
    class Railtie < ::Rails::Railtie
      initializer 'aws-xray.set_name' do |app|
        unless Aws::Xray.config.name
          app_name = app.class.parent_name.underscore.gsub(/(\/|_)/, '-')

          if Rails.env.production?
            Aws::Xray.config.name = app_name
          else
            Aws::Xray.config.name = "#{app_name}-#{Rails.env}"
          end
        end
      end

      initializer 'aws-xray.rack_middleware' do |app|
        app.middleware.use Aws::Xray::Rack
      end

      initializer 'aws-xray.subscribe_instrumentations' do |app|
        ActiveSupport::Notifications.subscribe('process_action.action_controller') do |_, _, _, _, data|
          if Aws::Xray::Context.started?
            Aws::Xray::Context.current.base_segment.add_annotation(
              'controller' => data[:controller].to_s,
              'action' => data[:action].to_s,
              'view_runtime' => data[:view_runtime],
              'db_runtime' => data[:db_runtime],
            )
          end
        end
      end
    end
  end
end
