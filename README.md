# aws-xray
[![Build Status](https://travis-ci.org/taiki45/aws-xray.svg?branch=master)](https://travis-ci.org/taiki45/aws-xray)
[![Gem Version](https://badge.fury.io/rb/aws-xray.svg)](https://badge.fury.io/rb/aws-xray)
[![Coverage Status](https://coveralls.io/repos/github/taiki45/aws-xray/badge.svg)](https://coveralls.io/github/taiki45/aws-xray)

The unofficial AWS X-Ray Tracing SDK for Ruby.
It enables you to capture in-coming HTTP requests and out-going HTTP requests and send them to xray-agent automatically.

AWS X-Ray is a ditributed tracing system. See more detail about AWS X-Ray at [official document](http://docs.aws.amazon.com/xray/latest/devguide/aws-xray.html).

## Features
- Propagatin support in both single and multi thread environment.
- Rack middleware.
- Faraday middleware.
- net/http hook.
- Tracing HTTP request/response.
- Tracing errors.
- Annotation and metadata support.
- Sampling support.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'aws-xray'
```

And then execute:

    $ bundle

## Usage
### Rails app
Just require `aws/xray/rails`. It uses your application name by default.
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
require 'aws/xray/faraday'
Faraday.new('...', headers: { 'Host' => 'down-stream-app-id' } ) do |builder|
  builder.use Aws::Xray::Faraday
  # ...
end
```

If you don't use any Service Discovery tools, pass the down stream app name to the Faraday middleware:

```ruby
require 'aws/xray/faraday'
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

  Aws::Xray.start_subsegment(name: 'fetch-user', remote: true) do |sub|
    # DB access or something to trace.
  end
end
```

### Hooks
You can enable all the hooks with:

```ruby
# Gemfile
gem 'aws-xray', require: 'aws/xray/hooks/all'
```

#### net/http hook
To monkey patch net/http and records out-going http requests automatically, just require `aws/xray/hooks/net_http`:

If you can pass headers for net/http client, you can setup subsegment name via `X-Aws-Xray-Name` header:

```ruby
Net::HTTP.start(host, port) do |http|
  req = Net::HTTP::Get.new(uri, { 'X-Aws-Xray-Name' => 'target-app' })
  http.request(req)
end
```

If you can't access headers, e.g. external client library like aws-sdk or dogapi-rb, setup subsegment name by `Aws::Xray.overwrite`:

```ruby
client = Aws::Sns::Client.new
response = Aws::Xray.overwrite(name: 'sns') do
  client.create_topic(...)
end
```

#### rsolr hook
When you want to name solr requests, use this hook by require `aws/xray/hooks/rsolr`. The typical usecase is you use local haproxy to proxy to solr instances and you want to distinguish these requests from other reqeusts using local haproxy.

If you want to give a specific name, configure it:

```ruby
Aws::Xray.config.solr_hook_name = 'solr-development'
```

### Multi threaded environment
Tracing context is thread local. To pass current tracing context, copy current tracing context:

```ruby
Thread.new(Aws::Xray.current_context.copy) do |context|
  Aws::Xray.with_given_context(context) do
    # Do something
  end
end
```

## Configurations
### X-Ray agent location
aws-xray does not send any trace data by default. Set `AWS_XRAY_LOCATION` environment variable like `AWS_XRAY_LOCATION=localhost:2000`
or set proper aws-agent location with configuration interface like `Aws::Xray.config.client_options = { host: "localhost", port: 2000 }`.

In container environments, we often run xray agent container beside application container.
For that case, pass `AWS_XRAY_LOCATION` environment variable to container to specify host and port of xray agent.

```bash
docker run --link xray:xray --env AWS_XRAY_LOCATION=xray:2000 my-application
```

### Sampling
Sampling rate should be a float within 0 to 1. Both 0 and 1 are acceptable.
e.g. 0 means never sampled, 1 means always sampled, 0.3 means 30% of requests (or traces in not Rack app) will be sampled.
The default sampling rate is undefined so you should set your own sampling rate on production system. 

Set sampling rate with `AWS_XRAY_SAMPLING_RATE` env var.

### Excluded paths
To avoid tracing health checking requests, use "excluded paths" configuration.

- Environment variable: `AWS_XRAY_EXCLUDED_PATHS=/health_check,/another_check`
- Global configuration: `Aws::Xray.config.excluded_paths = ['/health_check', '/another_check', %r{/token/.+}]`

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

For metadata:

```ruby
Aws::Xray.config.default_metadata = Aws::Xray.config.default_metadata.merge(key: ['some', 'meaningful', 'value'])
```

Note: See official document about annotation and metadata in AWS X-Ray.

### Error handlers
When aws-xray fails to send segments due to system call errors, it logs errors to stderr by default.
If you want to track these errors, for example with Sentry, you can configure your own error handler:

```ruby
Aws::Xray.config.segment_sending_error_handler = MyCustomErrorHandler.new
```

The error handler must be callable object and receive 2 arguments and 2 keyword arguments. See `Aws::Xray::DefaultErrorHandler` more detail.

Optionaly, aws-xray offers an error handler which integrats with Sentry. To use it:

```ruby
Aws::Xray.config.segment_sending_error_handler = Aws::Xray::ErrorHandlerWithSentry.new
```

### Recording caller of HTTP requests
Set `Aws::Xray.config.record_caller_of_http_requests = true` if you want investigate the caller of specific HTTP requests.
It records caller of net/http and Faraday middleware.

## Development

After checking out the repo, run `bin/setup` to install dependencies. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/taiki45/aws-xray.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
