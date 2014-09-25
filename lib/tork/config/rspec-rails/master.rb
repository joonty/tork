$LOAD_PATH.unshift 'spec' unless $LOAD_PATH.include? 'spec'
$LOAD_PATH.unshift 'lib' unless $LOAD_PATH.include? 'lib'
require 'rails_helper' if File.exist? 'spec/rails_helper.rb'
require './rails_helper' if File.exist? 'rails_helper.rb'
require 'rspec/autorun' if defined? RSpec
