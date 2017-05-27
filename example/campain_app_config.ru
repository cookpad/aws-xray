require 'pry'
require 'aws-xray'

Aws::Xray.config.name = 'campain-app'
use Aws::Xray::Rack

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
