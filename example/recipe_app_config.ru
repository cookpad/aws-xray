require 'pry'
require 'faraday'
require 'aws-xray'

user_app = ENV.fetch('USER_APP') # host:port
campain_app = ENV.fetch('CAMPAIN_APP') # host:port

Aws::Xray.config.name = 'recipe-app'
use Aws::Xray::Rack

run Proc.new {|env|
  user_client = Faraday.new(url: "http://#{user_app}/", headers: { 'Host' => 'user-app' }) do |builder|
    builder.use Aws::Xray::Faraday
    builder.adapter Faraday.default_adapter
  end
  user_res = user_client.get('/')

  campain_client = Faraday.new(url: "http://#{campain_app}/", headers: { 'Host' => 'campain-app' }) do |builder|
    builder.use Aws::Xray::Faraday
    builder.adapter Faraday.default_adapter
  end
  campain_res = campain_client.get('/')

  body = "awesome recipe by #{user_res.body}"
  if campain_res.body == '1'
    body << ': You got a campain!'
  end

  ['200', {'Content-Type' => 'text/plain'}, [body]]
}
