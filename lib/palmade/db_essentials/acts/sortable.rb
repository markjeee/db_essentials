module Palmade::DbEssentials
  module Acts
    module Sortable
      module ClassMethods
        def sortable?
          sortable_attribute.nil? ? false : true
        end

        def sortable_attribute
          case
          when column_names.include?('sort_order')
            'sort_order'
          else
            nil
          end
        end

        protected

        def sortable_attach_options(options)
          if options.include?(:sort_by)
            case options[:sort_by]
            when 'DESC'
              options[:order] = "#{table_name}.sort_order DESC"
            when 'ASC'
              options[:order] = "#{table_name}.sort_order ASC"
            when nil
              options.delete(:order)
            else
              unless options.include?(:order)
                options[:order] = "#{table_name}.sort_order DESC"
              end
            end
          else
            unless options.include?(:order)
              options[:order] = "#{table_name}.sort_order DESC"
            end
          end

          options
        end

        private

        def sortable_delete_keys(options)
          if sortable?
            returning(options.dup) do |sanitized_options|
              sanitized_options.delete(:sort_by)
            end
          else
            options
          end
        end

        def validate_find_options_with_sortable(options)
          validate_find_options_without_sortable(sortable_delete_keys(options))
        end

        def find_every_with_sortable(options)
          if sortable?
            sortable_attach_options(options)
          elsif options.include?(:include) && options[:include]
            options[:include] = [ options[:include] ] unless options[:include].is_a?(Array)
            options[:include].compact.each do |inc|
              if inc.is_a? Hash
                if reflect = reflect_on_association(inc.keys.first.to_sym)
                  unless reflect.klass.nil?
                    reflect.klass.sortable_attach_options(options) if reflect.klass.sortable?
                  end
                end
              else
                if reflect = reflect_on_association(inc.to_sym)
                  unless reflect.klass.nil?
                    reflect.klass.sortable_attach_options(options) if reflect.klass.sortable?
                  end
                end
              end
            end
          end

          find_every_without_sortable(options)
        end
      end

      def self.included(base)
        base.extend(ClassMethods)

        # extend class methods
        class << base
          alias_method_chain :find_every, :sortable
          alias_method_chain :validate_find_options, :sortable
        end
      end
    end
  end
end
