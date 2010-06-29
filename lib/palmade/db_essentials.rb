require 'ostruct'
require 'erb'

DB_ESSENTIALS_LIB_DIR = File.dirname(__FILE__)
DB_ESSENTIALS_ROOT_DIR = File.join(DB_ESSENTIALS_LIB_DIR, '../..')

module Palmade
  module DbEssentials
    def self.logger; @logger; end
    def self.logger=(l); @logger = l; end

    autoload :FindExtensions, File.join(DB_ESSENTIALS_LIB_DIR, 'db_essentials/find_extensions')
    autoload :Helpers, File.join(DB_ESSENTIALS_LIB_DIR, 'db_essentials/helpers')
    autoload :Acts, File.join(DB_ESSENTIALS_LIB_DIR, 'db_essentials/acts')

    module Extend; end

    def self.boot!(logger)
      self.logger = logger
    end
  end
end
