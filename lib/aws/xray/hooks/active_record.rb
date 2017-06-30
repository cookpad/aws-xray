require 'aws/xray'
require 'active_record'

module Aws
  module Xray
    module Hooks
      module ActiveRecord
        extend self

        IGNORE_NAMES = [nil, 'SCHEMA']

        # event has #name, #time, #end, #duration, #payload
        # payload has #sql, #name, #connection_id, #binds, #cached
        #
        # @param [ActiveSupport::Notifications::Event] e
        def record(e)
          return if IGNORE_NAMES.include?(e.payload[:name])

          if !e.payload[:cached] && Aws::Xray::Context.started?
            pool, con = fetch_connection_and_pool(e.payload[:connection_id])
            return if pool.nil? || con.nil?
            name = build_name(pool.spec)
            return unless name # skip when connected to default host (typycally localhost)

            Aws::Xray::Context.current.start_subsegment(name: name, remote: true) do |sub|
              sub.start(e.time)
              sub.finish(e.end)
              sub.set_sql(Aws::Xray::Sql.build(
                url: build_url(pool.spec),
                database_version: build_version(con),
              ))
            end
          end
        end

        private

        def fetch_connection_and_pool(id)
          pool, con = nil, nil
          ::ActiveRecord::Base.connection_handler.connection_pool_list.each do |p|
            p.connections.each do |c|
              if c.object_id == id
                pool, con = p, c
              end
            end
          end
          return pool, con
        end

        def build_name(spec)
          spec.config.with_indifferent_access[:host]
        end

        def build_url(spec)
          config = spec.config.with_indifferent_access
          adapter = config.delete(:adapter) || 'unknown'
          host = config.delete(:host) || 'localhost'
          port = config.delete(:port) || ''
          username = config.delete(:username) || ''
          database = config.delete(:database) || ''
          config.delete(:password)
          query = config.map {|k, v| "#{k}=#{v}" }.join('&')
          query_str = query.empty? ? '' : "?#{query}"
          "#{adapter}://#{username}@#{host}:#{port}/#{database}#{query_str}"
        end

        def build_version(con)
          if con.respond_to?(:version)
            if (v = con.version.instance_variable_get('@version'))
              v.join('.')
            else
              nil
            end
          else
            nil
          end
        end
      end
    end
  end
end

# maybe old version?
if defined?(ActiveSupport::Notifications) && ActiveSupport::Notifications.respond_to?(:subscribe)
  ActiveSupport::Notifications.subscribe('sql.active_record') do |*args|
    Aws::Xray::Hooks::ActiveRecord.record(ActiveSupport::Notifications::Event.new(*args))
  end
else
  $stderr.puts('Skip hooking active record events because this version of active record is not supported')
end
