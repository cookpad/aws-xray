# aws-xray
[![Build Status](https://travis-ci.org/taiki45/aws-xray.svg?branch=master)](https://travis-ci.org/taiki45/aws-xray)
[![Gem Version](https://badge.fury.io/rb/aws-xray.svg)](https://badge.fury.io/rb/aws-xray)

The unofficial AWS X-Ray Tracing SDK for Ruby.
It enables you to capture in-coming HTTP requests and out-going HTTP requests and send them to xray-agent automatically.

AWS X-Ray is a ditributed tracing system. See more detail about AWS X-Ray at [official document](http://docs.aws.amazon.com/xray/latest/devguide/aws-xray.html).

## Current status
Implemented:

- Rack middleware.
- Faraday middleware.
- Propagatin support limited in single thread environment.
- Tracing HTTP request/response.

Not yet:

- Multi thread support.
- Tracing errors.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'aws-xray'
```

And then execute:

    $ bundle

## Usage
### Rack app
```ruby
# config.ru
require 'aws-xray'
use Aws::Xray::Rack
```

This allow your app to trace in-coming HTTP requests.

To trace out-going HTTP requests, use Faraday middleware.

```ruby
Faraday.new('...', headers: { 'Host' => 'down-stream-app-id' } ) do |builder|
  builder.use Aws::Xray::Faraday
  # ...
end
```

If you don't use any Service Discovery tools, pass the down stream app name to the Faraday middleware:

```ruby
Faraday.new('...') do |builder|
  builder.use Aws::Xray::Faraday, name: 'down-stream-app-id'
  # ...
end
```

### non-Rack app (like background jobs)
```ruby
# Build HTTP client with Faraday builder.
# You can set the down stream app id to Host header as well.
client = Faraday.new('...') do |builder|
  builder.use Aws::Xray::Faraday, name: 'down-stream-app-id'
  # ...
end

# Start new tracing context then perform arbitrary actions in the block.
Aws::Xray::Context.with_new_context('test-app', xray_client, trace_header) do
  Aws::Xray::Context.current.base_trace do
    client.get('/foo')

    Aws::Xray::Context.current.child_trace do |sub|
      # DB access or something to trace.
    end
  end
end
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/taiki45/aws-xray.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
