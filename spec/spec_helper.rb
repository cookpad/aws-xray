require 'coveralls'
Coveralls.wear!

require 'pry'

$:.unshift File.expand_path('../lib', __dir__)
require 'aws/xray'
require 'aws/xray/hooks/all'

require 'fileutils'
require 'rack/test'
require 'webmock'

Aws::Xray.config.name = 'test-app'
Aws::Xray.config.version = -> { 'deadbeef' }
Aws::Xray.config.worker = Aws::Xray::Worker::Configuration.new(num: 1)
Aws::Xray.config.sampling_rate = 1
Aws::Xray.config.solr_hook_name = 'solr-test'

require 'json-schema'
# Json schema for `cause` object is invalid now.
# We don't have to set `cause` and `skipped` but it requires them.
# So we can't use json schema validation if segment contains errors.
module SegmentValidator
  path = File.expand_path('schema/xray-segmentdocument-schema-v1.0.0.json', __dir__)
  @schema = JSON.parse(File.read(path))

  def self.call(json)
    JSON::Validator.validate!(@schema, json)
  end
end

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups

  config.filter_run_when_matching :focus

  config.example_status_persistence_file_path = 'tmp/spec_examples.txt'

  config.disable_monkey_patching!

  config.warnings = false # because of rack-timeout

  if config.files_to_run.one?
    config.default_formatter = 'doc'
  end

  config.profile_examples = 10
  config.order = :random
  Kernel.srand config.seed
end
