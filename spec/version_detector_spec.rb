require 'spec_helper'
require 'fileutils'

RSpec.describe Aws::Xray::VersionDetector do
  specify do
    v = described_class.new
    FileUtils.rm_f('REVISION')
    expect(v.call).to be_nil
    File.write('REVISION', "deadbeef\n")
    expect(v.call).to eq('deadbeef')
    FileUtils.rm('REVISION')
  end
end
