module Palmade::DbEssentials
  module Acts
    module Misc
      module ClassMethods
        def is_association?(ks)
          reflect = reflect_on_association(ks.to_sym)
          if reflect
            reflect.macro
          else
            false
          end
        end

        def recreate_database
          connection.recreate_database(current_db_name)
          connection.reconnect!
        end

        def current_db_name
          if db_mysql?
            connection.select_value("SELECT DATABASE();")
          end
        end

        def reset_autoincrement_id(nextid = 1, tbl_name = nil)
          tbl_name ||= table_name
          if db_mysql?
            connection.execute("ALTER TABLE `#{tbl_name}` AUTO_INCREMENT = #{nextid};")
          end
        end

        def alter_to_utf8
          if db_mysql?
            connection.execute("ALTER DATABASE `#{current_db_name}` DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci;")
          end
        end

        def table_names
          if db_mysql?
            connection.select_values("SHOW TABLES;")
          end
        end

        def db_optimize
          if db_mysql?
            connection.execute("OPTIMIZE TABLE `#{table_name}`;")
          end
        end

        def db_engine
          if db_mysql?
            connection.select_one("SHOW TABLE STATUS LIKE '#{table_name}';")['Engine']
          end
        end

        def db_defrag
          if db_mysql?
            connection.execute("ALTER TABLE `#{table_name}` ENGINE = #{db_engine};")
          end
        end

        protected

        # the following methods are only applicable to mySQL
        def db_mysql?
          connection.is_a?(::ActiveRecord::ConnectionAdapters::MysqlAdapter)
        end
      end

      def poly_id
        "#{self.class.name},#{self.id}"
      end

      def db_id
        attributes['id']
      end

      def load_attributes
        attribute_names.each { |a| read_attribute(a) }
      end

      def copy_attributes(other, except = [ ])
        attr = { }
        other.class.column_names.each do |c|
          unless except.include?(c)
            if self.class.column_names.include?(c)
              attr[c] = other.attributes[c]
            end
          end
        end
        self.attributes = attr
      end

      def self.included(base)
        base.extend(ClassMethods)
      end
    end
  end
end
