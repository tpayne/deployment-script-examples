require 'spec_helper'
describe 'anime' do

  context 'with defaults for all parameters' do
    it { should contain_class('anime') }
  end
end
