require 'aws-xray'

use Aws::Xray::Rack, name: 'user-app'

run Proc.new {|env|
  ['200', {'Content-Type' => 'text/plain'}, ['user-1']]
}
