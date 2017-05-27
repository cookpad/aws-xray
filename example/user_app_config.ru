require 'pry'
require 'aws-xray'

Aws::Xray.config.name = 'user-app'
use Aws::Xray::Rack

run Proc.new {|env|
  ['200', {'Content-Type' => 'text/plain'}, ['user-1']]
}
