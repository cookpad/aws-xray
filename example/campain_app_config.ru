require 'aws-xray'

use Aws::Xray::Rack, name: 'campain-app'

run Proc.new {|env|
  ['200', {'Content-Type' => 'text/plain'}, ['0']]
}
