require 'pry'
require 'aws-xray'

use Aws::Xray::Rack, name: 'campain-app'

run Proc.new {|env|
  if rand(0..5) == 0
    ['500', {'Content-Type' => 'text/plain'}, ['-1']]
  else
    ['200', {'Content-Type' => 'text/plain'}, ['0']]
  end
}
