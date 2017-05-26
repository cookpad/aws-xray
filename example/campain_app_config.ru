require 'pry'
require 'aws-xray'

use Aws::Xray::Rack, name: 'campain-app'

class DbConnectionError < StandardError
  def initialize
    super('Could not connect to DB')
  end
end

run Proc.new {|env|
  if rand(0..1) == 0
    raise DbConnectionError
  else
    ['200', {'Content-Type' => 'text/plain'}, ['0']]
  end
}
