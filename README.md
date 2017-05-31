# aws-xray
[![Build Status](https://travis-ci.org/taiki45/aws-xray.svg?branch=master)](https://travis-ci.org/taiki45/aws-xray)
[![Gem Version](https://badge.fury.io/rb/aws-xray.svg)](https://badge.fury.io/rb/aws-xray)

The unofficial AWS X-Ray Tracing SDK for Ruby.
It enables you to capture in-coming HTTP requests and out-going HTTP requests and send them to xray-agent automatically.

AWS X-Ray is a ditributed tracing system. See more detail about AWS X-Ray at [official document](http://docs.aws.amazon.com/xray/latest/devguide/aws-xray.html).

## Features
- Rack middleware.
- Faraday middleware.
- Propagatin support limited in single thread environment.
- Tracing HTTP request/response.
- Tracing errors.
- Annotation and metadata support.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'aws-xray'
```

And then execute:

    $ bundle

## Usage
### Rails app
Insert Rack middleware by yourself:

```
# config/initializers/aws_xray.rb
Aws::Xray.config.name = 'my-app'
Rails.application.config.middleware.use Aws::Xray::Rack
```

Or just require `aws/xray/rails`. It uses your application name by default.
e.g. `Legacy::MyBlog` -> `legacy-my-blog`.

```ruby
# Gemfile
gem 'aws-xray', require: 'aws/xray/rails'
```

To trace out-going HTTP requests, see below.

### Rack app
```ruby
# config.ru
require 'aws-xray'
Aws::Xray.config.name = 'my-app'
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
  builder.use Aws::Xray::Faraday, 'down-stream-app-id'
  # ...
end
```

### non-Rack app (like background jobs)
```ruby
require 'aws-xray'

# Build HTTP client with Faraday builder.
# You can set the down stream app id to Host header as well.
client = Faraday.new('...') do |builder|
  builder.use Aws::Xray::Faraday, 'down-stream-app-id'
  # ...
end

# Start new tracing context then perform arbitrary actions in the block.
Aws::Xray.trace(name: 'my-app-batch') do |seg|
  client.get('/foo')

  Aws::Xray::Context.current.child_trace do |sub|
    # DB access or something to trace.
  end
end
```

## Configurations
### X-Ray agent location
aws-xray does not send any trace data default. Set `AWS_XRAY_LOCATION` environment variable like `AWS_XRAY_LOCATION=localhost:2000`
or set proper aws-agent location with configuration interface like `Aws::Xray.config.client_options = { host: "localhost", port: 2000 }`.

In container environments, we often run xray agent container beside application container.
For that case, pass `AWS_XRAY_LOCATION` environment variable to container to specify host and port of xray agent.

```
docker run --link xray:xray --env AWS_XRAY_LOCATION=xray:2000 my-application
```

### Excluded paths
To avoid tracing health checking requests, use "excluded paths" configuration.

- Environment variable: `AWS_XRAY_EXCLUDED_PATHS=/health_check,/another_check`
- Global configuration: `Aws::Xray.config.excluded_paths = %w[/health_check /another_check]`

### Recording application version
aws-xray automatically tries to set application version by reading `app_root/REVISION` file.
If you want to set another version, set it with:

```ruby
# In initialization phase.
Aws::Xray.config.version = 'deadbeef'
```

### Default annotation and metadata
aws-xray records hostname by default.

If you want to record specific annotation in all of your segments, configure like:

```ruby
Aws::Xray.config.default_annotation = Aws::Xray.config.default_annotation.merge(key: 'value')
```

Keys must be alphanumeric characters with underscore and values must be one of String or Integer or Boolean values.

For meta data:

```ruby
Aws::Xray.config.default_metadata = Aws::Xray.config.default_metadata.merge(key: ['some', 'meaningful', 'value'])
```

Note: See official document to know what annotation and metadata are in AWS X-Ray.

## Development

After checking out the repo, run `bin/setup` to install dependencies. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/taiki45/aws-xray.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
