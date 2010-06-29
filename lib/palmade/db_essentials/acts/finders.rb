module Palmade::DbEssentials
  module Acts
    module Finders
      self.const_set("HelperMethods", Palmade::DbEssentials::FindExtensions)

      module ExtendFind
        # stores the declared find modifiers
        def extend_find_modifiers(efm = nil)
          if defined?(@extend_find_modifiers)
            @extend_find_modifiers

          # it's either on AR::Base
          elsif self == ActiveRecord::Base
            nil

          # the parent class is not extended with finders,
          # or already ActiveRecord::Base
          elsif !self.superclass.respond_to?(:extend_find_modifiers) ||
              self.superclass.extend_find_modifiers.nil?

            # note, if we are an abtract class, note, we're going to have some
            # serious errors when trying to figure out table name
            @extend_find_modifiers = Palmade::DbEssentials::FindExtensions.new(self)

          # if we are an abstract_class, then we use our parent, as is!
          elsif self.abstract_class
            self.superclass.extend_find_modifiers

          # otherwise, we can just do a child copy
          else
            @extend_find_modifiers = self.superclass.extend_find_modifiers.child_copy(self)

          end
        end

        protected

        def extend_find(*args, &find_block)
          options = HelperMethods.extend_find_args(*args, &find_block)

          # if contains otherwise, add an :unless modifier
          if options.key?(:otherwise)
            extend_find_unless(args[0], options[:otherwise])
          end

          extend_find_modifiers.add(args[0], options)
        end

        def extend_find_builtin(opt_k, opt_v)
          modf = HelperMethods.build_modifier_with_option(self, opt_k, opt_v)
          unless modf.nil? || modf.empty? || modf.include?(:dynamic)
            extend_find_modifiers.add(opt_k, modf)
          else
            raise "Can't define builtin, got: #{modf.inspect} with args #{opt_k} => #{opt_v.inspect}"
          end
        end

        def extend_find_any(*args, &find_block)
          extend_find_modifiers.add(args[0], { :where_join => :any }.merge(HelperMethods.extend_find_args(*args, &find_block)))
        end

        def extend_find_order(*args, &find_block)
          extend_find_modifiers.add(args[0], { :type => :order }.merge(HelperMethods.extend_find_args(*args, &find_block)))
        end

        def extend_find_alias(with_opts, with_alias_opts)
          extend_find_modifiers.add(with_opts, { :type => :alias, :alias => with_alias_opts })
        end

        def extend_find_unless(*args, &find_block)
          extend_find_modifiers.modf_unless[args[0]] = HelperMethods.extend_find_args(*args, &find_block)
        end
      end

      module ClassMethods
        def calculate_with_finders(*args)
          options = args.last.is_a?(Hash) ? args.pop : { }
          with_extend_scope(options) do |sanitized_options|
            calculate_without_finders(*args.push(sanitized_options))
          end
        end

        # pass a block, and it will do a with_scope on that block
        # otherwise, it will return a :find scope parameter
        def with_extend_scope(options, &block)
          sanitized_options, scope = build_find_scope(options)

          if block_given?
            if scope.empty?
              yield(sanitized_options)
            else
              with_scope({ :find => scope }, :merge) do
                yield(sanitized_options)
              end
            end
          else
            [ sanitized_options, scope ]
          end
        end

        def build_find_scope(options)
          extend_find_modifiers.cheap_copy.process(options)
        end

        private

        # extend find_every method, which is basically the bottom level find every
        def find_every_with_finders(options)
          with_extend_scope(options) do |sanitized_options|
            find_every_without_finders(sanitized_options)
          end
        end

        # sanitize :with_XXX find options
        def validate_find_options_with_finders(options)
          validate_find_options_without_finders(HelperMethods.extend_delete_keys(self, options))
        end

        # sanitize :with_XXX find options
        def validate_calculation_options_with_finders(operation, options)
          validate_calculation_options_without_finders(operation, HelperMethods.extend_delete_keys(self, options))
        end
      end

      def self.included(base)
        base.extend(ClassMethods)
        base.extend(ExtendFind)

        class << base
          alias_method_chain :find_every, :finders
          alias_method_chain :validate_find_options, :finders
          alias_method_chain :calculate, :finders
          alias_method_chain :validate_calculation_options, :finders
        end
      end
    end
  end
end
