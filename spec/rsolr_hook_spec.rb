require 'spec_helper'

RSpec.describe Aws::Xray::Hooks::Rsolr do
  around do |ex|
    WebMock.enable!
    ex.run
    WebMock.disable!
  end
  before { WebMock.stub_request(:head, 'http://localhost:8983/admin/ping?wt=json') }

  specify do
    solr = RSolr.connect(url: 'http://localhost:8983')
    expect(Aws::Xray).to receive(:overwrite).with(name: 'solr-test').and_call_original

    Aws::Xray.trace(name: 'test') do
      expect(solr.head('admin/ping')).to eq({})
    end
  end
end
