require 'pry'
require 'faraday'
require 'aws-xray'

recipe_app = ENV.fetch('RECIPE_APP') # host:port

Aws::Xray.config.name = 'front-app'
use Aws::Xray::Rack

run Proc.new {|env|
  headers = { 'Host' => 'recipe-app' }
  client = Faraday.new(url: "http://#{recipe_app}/", headers: headers) do |builder|
    builder.use Aws::Xray::Faraday
    builder.adapter Faraday.default_adapter
  end
  res = client.get('/')

  body = "recipe_app returns: #{res.status}, #{res.body}"
  ['200', {'Content-Type' => 'text/plain'}, [body]]
}
