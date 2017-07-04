require 'spec_helper'

RSpec.describe Aws::Xray::Worker do
  specify do
    Aws::Xray::Worker.post(nil)
  end
end
