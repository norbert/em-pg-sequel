ENV['BUNDLE_GEMFILE'] = File.expand_path('../../Gemfile', __FILE__)

require 'bundler/setup'
require 'em-pg-sequel'

require 'logger'
require 'minitest/spec'
require 'minitest/autorun'
require 'minitest/reporters'

DB_CONFIG = {
  host: "localhost",
  port: 5432,
  dbname: "postgres",
  user: "postgres",
  password: "postgres",
}

DB_URL = "pgsynchrony://%s:%s@%s:%d/%s" % [DB_CONFIG[:user], DB_CONFIG[:password], DB_CONFIG[:host], DB_CONFIG[:port], DB_CONFIG[:dbname]]

MiniTest::Reporters.use! MiniTest::Reporters::SpecReporter.new
