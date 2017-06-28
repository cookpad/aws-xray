require 'spec_helper'

RSpec.describe Aws::Xray::Hooks::ActiveRecord do
  before { allow(Aws::Xray.config).to receive(:client_options).and_return(sock: io) }
  let(:io) { Aws::Xray::TestSocket.new }

  specify do
    Item.create!(name: 'a')

    Aws::Xray.trace(name: 'test') do
      Item.where(name: 'a').first
    end

    body = JSON.parse(io.tap(&:rewind).read.split("\n")[1])
    expect(body['sql']).to be_a(Hash)
    expect(body['sql']['url']).to eq('sqlite3://root@localhost:/db/test.sqlite3?timeout=1')
    expect(body['sql']['database_version']).to be_nil
  end
end
