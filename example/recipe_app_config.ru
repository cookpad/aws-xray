require 'aws-xray'

use Aws::Xray::Rack, name: 'recipe-app'

run Proc.new {|env|
  ['200', {'Content-Type' => 'text/plain'}, ['awesome recipe']]
}
