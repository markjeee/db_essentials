module Palmade::DbEssentials::Helpers
  module ActiveRecord2Helper
    def self.setup(config)
      silence_warnings { Object.const_set("DB_ESSENTIALS_TARGET_ROOT", config.root_path) }
      silence_warnings { Object.const_set("DB_ESSENTIALS_ENV", config.environment) }

      [ 'extend/active_record2/extend',
        'extend/active_record2/connection_adapters/abstract/connection_specification',
        'extend/active_record2/connection_adapters/abstract/connection_pool'
      ].each do |r|
        require File.join(DB_ESSENTIALS_LIB_DIR, r)
      end

      ActiveRecord::Base.send(:include, Palmade::DbEssentials::Acts::TableName)
      ActiveRecord::Base.send(:include, Palmade::DbEssentials::Acts::Misc)

      ActiveRecord::Observer.send(:include, Palmade::DbEssentials::Acts::ObserverExtensions)
    end
  end
end
