require 'pry'

require 'net/http'

require 'faraday'
require 'aws-xray'
require 'aws/xray/faraday'
require 'aws/xray/hooks/net_http'

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

  uri = URI("http://#{campain_app}")
  host, port = campain_app.split(':')
  campain_res = Net::HTTP.start(host, port) do |http|
    http.request(Net::HTTP::Get.new(uri))
  end

  body = "awesome recipe by #{user_res.body}"
  if campain_res.body == '1'
    body << ': You got a campain!'
  end

  ['200', {'Content-Type' => 'text/plain'}, [body]]
}
