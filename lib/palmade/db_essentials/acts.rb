module Palmade::DbEssentials
  module Acts
    autoload :Finders, File.join(DB_ESSENTIALS_LIB_DIR, 'db_essentials/acts/finders.rb')
    autoload :Misc, File.join(DB_ESSENTIALS_LIB_DIR, 'db_essentials/acts/misc.rb')
    autoload :Sortable, File.join(DB_ESSENTIALS_LIB_DIR, 'db_essentials/acts/sortable.rb')
    autoload :TableName, File.join(DB_ESSENTIALS_LIB_DIR, 'db_essentials/acts/table_name.rb')
    autoload :ObserverExtensions, File.join(DB_ESSENTIALS_LIB_DIR, 'db_essentials/acts/observer_extensions.rb')
    autoload :PostCallback, File.join(DB_ESSENTIALS_LIB_DIR, 'db_essentials/acts/post_callback.rb')
  end
end
