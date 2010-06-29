module Palmade
  module DbEssentials
    module Acts
      module ObserverExtensions
        module ClassMethods
          def logger
            ActiveRecord::Base.logger
          end
        end

        def logger
          self.class.logger
        end

        def self.included(base)
          base.extend(ClassMethods)
        end
      end
    end
  end
end
