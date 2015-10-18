source 'https://rubygems.org'

puppetversion = ENV.key?('PUPPET_VERSION') ? "#{ENV['PUPPET_VERSION']}" : ['>= 3.3']
# We specify json version that is bundled with ruby 2, t prevent bundler trying to install a remote version that requires the dev kit to build locally.
gem 'json', '1.8.1'
gem 'puppet', puppetversion
gem 'puppetlabs_spec_helper', '>= 0.8.2'
gem 'puppet-lint', '>= 1.0.0'
gem 'facter', '>= 1.7.0'
gem 'r10k'
gem 'librarian-puppet'
