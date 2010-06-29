module Palmade::DbEssentials
  module Acts
    module TableName
      module ClassMethods
        def table_name_with_db_essentials
          if self.abstract_class?
            self.superclass.table_name
          elsif self == ActiveRecord::Base
            nil
          else
            table_name_without_db_essentials
          end
        end

        def set_table_name_with_db_essentials(value)
          if self.abstract_class? ||
              self == ActiveRecord::Base
            raise ArgumentError, "#{self.name} can't have a table_name, either an abstract class or is ActiveRecord::Base"
          else
            set_table_name_without_db_essentials(value)
          end
        end
      end

      def self.included(base)
        base.extend(ClassMethods)

        class << base
          alias_method_chain :set_table_name, :db_essentials
          alias_method_chain :table_name, :db_essentials
        end
      end
    end
  end
end
