# aws-xray
[![Build Status](https://travis-ci.org/taiki45/aws-xray.svg?branch=master)](https://travis-ci.org/taiki45/aws-xray)
[![Gem Version](https://badge.fury.io/rb/aws-xray.svg)](https://badge.fury.io/rb/aws-xray)
[![Coverage Status](https://coveralls.io/repos/github/taiki45/aws-xray/badge.svg)](https://coveralls.io/github/taiki45/aws-xray)

The unofficial AWS X-Ray Tracing SDK for Ruby.
It enables you to capture in-coming HTTP requests and out-going HTTP requests and send them to xray-agent automatically.

AWS X-Ray is a distributed tracing system. See more detail about AWS X-Ray at [official document](http://docs.aws.amazon.com/xray/latest/devguide/aws-xray.html).
If you want to know what is distributed tracing, what is problems behind, etc.., please refer [Google's Dapper paper](https://research.google.com/pubs/pub36356.html).

## Features
aws-xray has full feautres to build and send tracing data to AWS X-Ray.

- Propagatin support in both single and multi thread environment.
- Instrumentation for major libraries.
- Recording HTTP request/response and errors.
- Annotation and metadata support.
- Sampling.

## Supported libraries
- net/http
- rack
- faraday
- activerecord
- rsolr

## Getting started
### Rails app
Just require `aws/xray/rails`. It uses your application name by default. e.g. `Legacy::MyBlog` -> `legacy-my-blog`.

```ruby
# Gemfile
gem 'aws-xray', require: ['aws/xray/rails', 'aws/xray/hooks/net_http']
```

Requiring `aws/xray/rails` inserts Rack middleware to the middleware stack and the middleware automatically starts tracing context. Another requiring `aws/xray/hooks/net_http` inserts a hook to net/http and it records out-going HTTP requests/responses automatically.

Then setup [X-Ray daemon](http://docs.aws.amazon.com/xray/latest/devguide/xray-daemon.html) in your runtime environment.
Once the daemon is ready, run your application with some environment variable required by aws-xray gem.

- `AWS_XRAY_LOCATION`: Point to X-Ray daemon's bind address and port. e.g. `localhost:2000`.
- `AWS_XRAY_SAMPLING_RATE`: Set sampling rate. If you are just checking behavior, you can disable sampling by setting `1`.
- `AWS_XRAY_EXCLUDED_PATHS`: Set your application's health check paths to avoid tracing health check requests.

You then see your application builds and sends tracing data to X-Ray daemon.

## Configurations
### Summary
Recommend setting these operatinal concern via environment variables.

Name | Env var | Ruby interface
-- | -- | --
X-Ray daemon location | `AWS_XRAY_LOCATION` | `config.client_options`
Sampling rate | `AWS_XRAY_SAMPLING_RATE` | `config.sampling_rate`
Excluded paths | `AWS_XRAY_EXCLUDED_PATHS` | `config.excluded_paths`
Application name | `AWS_XRAY_NAME` | `config.name`

See more configuration at [API documentation](http://www.rubydoc.info/gems/aws-xray/Aws/Xray/Configuration).

### X-Ray daemon location
aws-xray does not send any trace data by default. Set `AWS_XRAY_LOCATION` environment variable like `AWS_XRAY_LOCATION=localhost:2000`.

In container environments, we run X-Ray daemon container beside application container.
For that case, pass `AWS_XRAY_LOCATION` environment variable to container to specify host and port of X-Ray daemon.

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

## Usage
### Multi threaded environment
Tracing context is thread local. To pass current tracing context, copy current tracing context:

```ruby
Thread.new(Aws::Xray.current_context.copy) do |context|
  Aws::Xray.with_given_context(context) do
    # Do something
  end
end
```

### Background jobs or offline processing
```ruby
require 'aws/xray'
require 'aws/xray/hooks/net_http'

# Start new tracing context then perform arbitrary actions in the block.
Aws::Xray.trace(name: 'my-app-batch') do |seg|
  # Record out-going HTTP request/response with net/http hook.
  Net::HTTP.get('example.com', '/index.html')

  # Record arbitrary actions as subsegment.
  Aws::Xray.start_subsegment(name: 'fetch-user', remote: true) do |sub|
    # DB access or something to trace.
  end
end
```

### Rack middleware
```ruby
# config.ru
require 'aws-xray'
Aws::Xray.config.name = 'my-app'
use Aws::Xray::Rack
```

This enables your app to start tracing context.

### Faraday middleware
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

#### activerecord hook
`require 'aws/xray/hooks/active_record'`.

Note this hook can record large amount of data.

#### rsolr hook
When you want to name solr requests, use this hook by require `aws/xray/hooks/rsolr`. The typical usecase is you use local haproxy to proxy to solr instances and you want to distinguish these requests from other reqeusts using local haproxy.

If you want to give a specific name, configure it:

```ruby
Aws::Xray.config.solr_hook_name = 'solr-development'
```
