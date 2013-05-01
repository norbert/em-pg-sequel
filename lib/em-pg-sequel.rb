require 'pg'
require 'pg/em'
require 'em-synchrony'
require 'em-synchrony/pg'
require 'sequel'
require 'sequel/adapters/postgres'

# Who knows which modules are defined at this point?
module EM; module PG; module Sequel; end; end; end
require 'em-pg-sequel/adapter'
require 'em-pg-sequel/connection_pool'
