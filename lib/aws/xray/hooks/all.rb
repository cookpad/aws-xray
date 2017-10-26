# Don't require activerecord hook because the hook may produce lots of trace records.
require 'aws/xray'
require 'aws/xray/hooks/net_http'
require 'aws/xray/hooks/rsolr'
