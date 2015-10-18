require 'spec_helper'
describe 'imwops_bootstrap' do

  context 'with defaults for all parameters' do
    it { should contain_class('imwops_bootstrap') }
  end
end
