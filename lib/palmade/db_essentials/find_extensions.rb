# !!!! BIG NOTE !!!!
# THIS CODE IS NOT THREAD-SAFE!

module Palmade::DbEssentials
  class FindExtensions
    def self.build_modifier_with_option(klass, opt_k, opt_v)
      if opt_k.to_s =~ /^with\_(.+)/
        ks, k_type, comp_modifier = extend_parse_key(klass, $~[1].dup)

        table_name = klass.table_name
        modf = { }

        case k_type
        when :attribute
          case opt_v
          when Range, Array
            modf[:vtype] = opt_v.class

            case comp_modifier
            when nil
              modf[:modifier] = "#{table_name}.#{ks} IN (:#{opt_k})"
            when 'ne', 'not_equal'
              modf[:modifier] = "#{table_name}.#{ks} NOT IN (:#{opt_k})"
            else
              modf[:between] = true

              comp_op = case comp_modifier
                        when 'between', 'bt'
                          [ '>', '<' ]
                        when 'within', 'wt'
                          [ '>=', '<=' ]
                        when 'from_to', 'ft'
                          [ '>=', '<' ]
                        when 'to_from', 'tf'
                          [ '>', '<=' ]
                        else
                          nil
                        end

              # if we comparing, with only two values
              # then this can work
              if comp_op
                modf[:modifier] = [ 0, 1 ].collect { |i|
                  "#{ks} #{comp_op[i]} :#{opt_k}_#{i == 0 ? 'from' : 'to'}"
                }.compact.join(' AND ')
              else
                modf[:modifier] = "#{table_name}.#{ks} IN (:#{opt_k})"
              end
            end
          else
            case comp_modifier
            when 'greater_than', 'later_than', 'gt'
              modf[:modifier] = "#{table_name}.#{ks} > :#{opt_k}"
            when 'greater_than_equal', 'later_than_equal', 'gte', 'ate'
              modf[:modifier] = "#{table_name}.#{ks} >= :#{opt_k}"
            when 'lesser_than', 'earlier_than', 'lt', 'et'
              modf[:modifier] = "#{table_name}.#{ks} < :#{opt_k}"
            when 'lesser_than_equal', 'earlier_than_equal', 'lte', 'ete'
              modf[:modifier] = "#{table_name}.#{ks} <= :#{opt_k}"
            when 'not_equal', 'ne'
              if opt_v.nil?
                modf[:modifier] = "#{table_name}.#{ks} IS NOT NULL"
                modf[:vtype] = nil
              else
                modf[:modifier] = "#{table_name}.#{ks} != :#{opt_k}"
              end
            when 'not_like'
              modf[:modifier] = "NOT #{table_name}.#{ks} LIKE :#{opt_k}"
            when 'like'
              modf[:modifier] = "#{table_name}.#{ks} LIKE :#{opt_k}"
            when 'is_null'
              if opt_v === true
                modf[:modifier] = "#{table_name}.#{ks} IS NULL"
                modf[:vtype] = true
              elsif opt_v === false
                modf[:modifier] = "#{table_name}.#{ks} IS NOT NULL"
                modf[:vtype] = false
              else
                raise ArgumentError, "Expecting either true or false value"
              end
            else
              if opt_v.nil?
                modf[:modifier] = "#{table_name}.#{ks} IS NULL"
                modf[:vtype] = nil
              else
                modf[:modifier] = "#{table_name}.#{ks} = :#{opt_k}"
              end
            end
          end
        when :association
          reflect = klass.reflect_on_association(ks.to_sym)

          if reflect.options[:polymorphic]
            # we're going to mark this as polymorphic
            modf[:polymorphic] = reflect.name

            case opt_v
            when nil
              modf[:modifier] = "#{table_name}.#{reflect.primary_key_name} IS NULL" +
                " AND #{table_name}.#{reflect.options[:foreign_type]} IS NULL"
              modf[:vtype] = nil
            when Array
              types = Set.new
              opt_v.each { |v| types.add(v.class.name) }

              modf[:modifier] = types.collect { |tp_k|
                "(#{table_name}.#{reflect.options[:foreign_type]} = :with_#{modf[:polymorphic].to_s}_#{tp_k}_type" +
                " AND #{table_name}.#{reflect.primary_key_name} IN (:with_#{modf[:polymorphic].to_s}_#{tp_k}_id))"
              }.join(" OR ")

              # must match *all* these types
              modf[:vtype] = types
            else
              case comp_modifier
              when 'is_null'
                if opt_v === true
                  modf[:modifier] = "#{table_name}.#{reflect.primary_key_name} IS NULL" +
                    " AND #{table_name}.#{reflect.options[:foreign_type]} IS NULL"
                  modf[:vtype] = true
                elsif opt_v === false
                  modf[:modifier] = "#{table_name}.#{reflect.primary_key_name} IS NOT NULL" +
                    " AND #{table_name}.#{reflect.options[:foreign_type]} IS NOT NULL"
                  modf[:vtype] = false
                else
                  modf[:modifier] = "0"
                  modf[:dynamic] = true # don't save as a modifier
                end
              else
                modf[:modifier] = "#{table_name}.#{reflect.primary_key_name} = :with_#{modf[:polymorphic].to_s}_id" +
                  " AND #{table_name}.#{reflect.options[:foreign_type]} = :with_#{modf[:polymorphic].to_s}_type"
              end
            end
          else
            case opt_v
            when Range, Array
              modf[:modifier] = "#{table_name}.#{reflect.primary_key_name} IN (:#{opt_k})"
              modf[:vtype] = opt_v.class
            when nil
              modf[:modifier] = "#{table_name}.#{reflect.primary_key_name} IS NULL"
              modf[:vtype] = nil
            else
              case comp_modifier
              when 'is_null'
                if opt_v === true
                  modf[:modifier] = "#{table_name}.#{reflect.primary_key_name} IS NULL"
                  modf[:vtype] = true
                elsif opt_v === false
                  modf[:modifier] = "#{table_name}.#{reflect.primary_key_name} IS NOT NULL"
                  modf[:vtype] = false
                else
                  modf[:modifier] = "0"

                  # prevent this from being saved as a modifier
                  modf[:dynamic] = true
                end
              else
                # this checks if this is an actual class that this reflection is referring to
                # to avoid mis-using
                if opt_v.is_a?(::ActiveRecord::Base) && opt_v.is_a?(reflect.klass)
                  # this can be saved, but can only match to this particular class
                  # it is restricted based on our relationship (foreign class)
                  modf[:modifier] = "#{table_name}.#{reflect.primary_key_name} = :#{opt_k}"
                  modf[:vtype] = reflect.klass
                elsif opt_v.is_a?(Numeric)
                  modf[:modifier] = "#{table_name}.#{reflect.primary_key_name} = :#{opt_k}"
                  modf[:vtype] = Numeric
                elsif opt_v.is_a?(String)
                  modf[:modifier] = "#{table_name}.#{reflect.primary_key_name} = :#{opt_k}"
                  modf[:vtype] = String
                else
                  modf[:modifier] = "0"

                  # prevent this from being saved as a modifier, since it's
                  # reflects as every other types of class
                  modf[:dynamic] = true
                end
              end
            end
          end
        end

        modf.empty? ? nil : modf
      else
        nil
      end
    end

    # formats the extend_find argument declaration
    def self.extend_find_args(*args, &find_block)
      case args.size
      when 3
        args[2].merge({ :modifier => args[1], :find_block => find_block })
      when 2
        if args.last.is_a?(Hash)
          args.last.merge({ :find_block => find_block })
        else
          { :modifier => args.last, :find_block => find_block }
        end
      else
        { :find_block => find_block }
      end
    end

    def self.extend_parse_key(klass, ks)
      # check for comparison modifier, and slice it now!
      comp_modifier = nil
      for comp_m in [ 'greater_than', 'greater_than_equal', 'gt', 'gte',
                      'later_than', 'later_than_equal', 'ate',
                      'lesser_than', 'lesser_than_equal', 'lt', 'lte',
                      'earlier_than', 'earlier_than_equal', 'et', 'ete',
                      'between', 'bt', 'within', 'wt',
                      'from_to', 'ft',
                      'to_from', 'tr',
                      'not_equal', 'ne',
                      'not_like', 'like',
                      'is_null' ].freeze

        if ks.ends_with?(comp_m)
          comp_modifier = comp_m
          ks.slice!(/\_#{comp_m}$/)
          break
        end
      end

      # = check if it is an attribute
      k_type = if klass.column_names.include?(ks)
                 :attribute
                 # = check if it is an association (via reflection), works *ONLY* with :belongs_to
               elsif reflect = klass.reflect_on_association(ks.to_sym)
                 reflect.macro == :belongs_to ? :association : nil
                 # = check if it is an extended relationship key (not yet implemented)
               else
                 nil
               end

      [ ks, k_type, comp_modifier ]
    end

    def self.extend_delete_keys(klass, options)
      options.dup.delete_if do |opt_k, opt_v|
        if opt_k.to_s =~ /^with\_(.+)/
          ks = $~[1].dup

          # check if this is a declared extend find modifier
          if klass.extend_find_modifiers.include?(opt_k, opt_v)
            true

          # check if this is an unless (otherwise) extend find modifier
          elsif !klass.extend_find_modifiers[:unless].nil? && klass.extend_find_modifiers[:unless].include?(opt_k)
            true

          # otherwise, we'll see if this is a built-in modifier
          else
            ks, k_type, comp_modifier = extend_parse_key(klass, ks)
            k_type.nil? ? false : true
          end
        else
          false
        end
      end
    end

    DEFAULT_JOIN_CONDITION = ' AND '
    attr_reader :ar
    attr_reader :options

    def initialize(ar, modifiers = { })
      @ar = ar
      @modifiers = modifiers
    end

    def []=(k, v)
      @modifiers[k] = v
    end

    def [](k)
      @modifiers[k]
    end

    def cheap_copy
      self.class.new(@ar, @modifiers)
    end

    def child_copy(ar)
      new_m = { }

      @modifiers.each do |k, v|
        if k == :unless
          new_m[:unless] = { }
          v.each do |k1,v1|
            new_m[:unless][k1] = v1
          end
        # copy a multi-value modifier
        elsif v.is_a?(Array)
          new_m[k] = [ ].concat(v)
        else
          new_m[k] = v
        end
      end

      self.class.new(ar, new_m)
    end

    def modf_unless
      if @modifiers.include?(:unless)
        @modifiers[:unless]
      else
        @modifiers[:unless] = { }
      end
    end

    def include?(opt_k, opt_v)
      !get_modifier(opt_k, opt_v).nil?
    end
    alias :key? :include?
    alias :has_key? :include?

    def get_modifier(opt_k, opt_v)
      if @modifiers.include?(opt_k)
        if @modifiers[opt_k].is_a?(Array)
          # let's match the value to possible items
          # 1) go through all entries, and find an exact match
          # 2) if there's no match, find the non-value specific match (no :vtype)
          # 3) the last non-value specific match wins!

          # let's build up the set of classes for this opt_v
          types = Set.new
          if opt_v.is_a?(Array)
            opt_v.each do |v|
              types.add(v.class.name)
            end
          else
            types.add(opt_v.class.name)
          end

#true (value is true),
#false (value is false),
#nil (value is nil),
#Class (must be this class),
#Set (exact set of classes),

          # let's find all the matching modifiers
          matches = @modifiers[opt_k].select do |modf|
            if modf.include?(:vtype)
              case modf[:vtype]
              when true
                opt_v === true
              when false
                opt_v === false
              when nil
                opt_v.nil?
              when Class
                opt_v.is_a?(modf[:vtype])
              when Set
                types == modf[:vtype]
              else
                raise ArgumentError, "Unsupported value type: #{modf[:vtype]}"
              end
            else
              true
            end
          end

          unless matches.empty?
            matched = nil
            matches.each do |m|
              # if we found our first exact match based on value, we go for it!
              if m.include?(:vtype)
                matched = m
                break
              # otherwise, we just save the last non-valued based match, for later
              else
                matched = m
              end
            end
            matched
          else
            nil
          end
        else
          @modifiers[opt_k]
        end
      else
        nil
      end
    end

    def add(modk, modf)
      if modf.include?(:vtype) || @modifiers[modk].is_a?(Array)
        # we need it to be an array already
        # so we convert it, in case it's not
        unless @modifiers[modk].is_a?(Array)
          @modifiers[modk] = [ @modifiers[modk] ].compact
        end
        @modifiers[modk].push(modf)
      else
        @modifiers[modk] = modf
      end
    end

    def prepare_for_processing
      @include_models = [ ]
      @conditions = [ ]
      @order = [ ]

      @opt_v = [ ]
      @join_condition_modifier = DEFAULT_JOIN_CONDITION
    end

    def process(options)
      # let's duplicate the options
      # note, @options is used here for backward compatibility
      @options = options = options.dup

      # let's empty our scope, for new processing
      prepare_for_processing

      matched_keys = [ ]
      for opt_k in options.keys
        if opt_k.to_s =~ /^with\_(.+)/ && process_with_option(options, opt_k, options[opt_k])
          matched_keys << opt_k
        end
      end

      # let's add our :unless modifiers
      if @modifiers.key?(:unless) && @modifiers[:unless].size > 0
        for unless_k in @modifiers[:unless].keys
          unless options.include?(unless_k)
            do_option(options, nil, nil, @modifiers[:unless][unless_k])
          end
        end
      end

      # let's remove the matched :with_keys
      options.delete_if { |opt_k, opt_v| matched_keys.include?(opt_k) }

      # let's build our scope
      build_options_and_scope(options)
    end

    protected

    def build_options_and_scope(options)
      scope = { }

      # add include scope if any
      unless @include_models.empty?
        scope[:include] = @include_models.compact.uniq
      end

      # delete empty or nil conditions
      @conditions.delete_if { |cond| (cond.nil? || cond.empty? || cond.strip.empty?) }

      # unless conditions is empty, let's add it into scope
      unless @conditions.empty?
        scope[:conditions] = @conditions.collect { |cond| "(#{cond})" }.join(@join_condition_modifier)
      end

      # just use the last order by clause, based on precedence
      unless @order.empty?
        options[:order] = @order.last
      end

      [ options, scope ]
    end

    def include_model(model)
      case model
        when Array
          @include_models += model
        else
          @include_models << model
      end
    end

    def condition(conds)
      if conds[1].is_a?(Hash)
        conds[1].delete_if { |k,v| !conds[0].include?(":" + k.to_s) }
        conds.delete_at(1) if (conds[1].nil? || conds[1].empty?)
      end

      cond_sql = @ar.send(:sanitize_sql, conds).strip
      if cond_sql.size > 0
        @conditions << cond_sql
      end
    end

    def order(ordr)
      order_sql = @ar.send(:sanitize_sql, ordr).strip
      if order_sql.size > 0
        @order << order_sql
      end
    end

    private

    def build_modifier_with_option(opt_k, opt_v)
      modf = self.class.build_modifier_with_option(ar, opt_k, opt_v)
      unless modf.nil? || modf.empty? # || modf.include?(:dynamic)
        # ar.logger.debug("MODF :#{opt_k} #{modf.inspect}")
        modf
      else
        nil
      end
    end

    def process_builtin_with_option(options, opt_k, opt_v = nil)
      process_with_option(options, opt_k, opt_v, true)
    end

    def process_with_option(options, opt_k, opt_v = nil, force_built_in = false)
      # check if this is a defined modifier
      if !force_built_in && include?(opt_k, opt_v)
        do_option(options, opt_k, opt_v, get_modifier(opt_k, opt_v)); true

      # check if this is a built-in modifier (based on column or relationship)
      elsif modf = build_modifier_with_option(opt_k, opt_v)
        do_option(options, opt_k, opt_v, modf); true

      # alrighty, not defined or built-in, let's drop it!
      else
        false
      end
    end

    MODF_KEYS = [ :type, :modifier, :include_model, :then, :else,
                  :if, :unless, :otherwise, :polymorphic, :between,
                  :if_null, :where_join, :vtype, :dynamic ]

    def do_option(options, opt_k, opt_v, modf)
      @opt_v.push(opt_v)

      if applies?(options, opt_k, opt_v, modf)
        case modf[:type]
        when :alias
          process_with_option(options, modf[:alias], opt_v)
        else
          if modf.key?(:include_model)
            include_model(modf[:include_model])
          end

          if modf[:where_join] && modf[:where_join].to_s == "any"
            @join_condition_modifier = ' OR '
          end

          if modf[:find_block]
            instance_eval(&modf[:find_block])
          else
            ext_opts = modf.reject { |k,v| MODF_KEYS.include?(k) }

            # check for class-based modifiers
            modifier = nil
            for e_k, e_v in ext_opts
              case e_k
              when Array
                for e_k_c in e_k
                  if opt_v.is_a?(e_k_c)
                    modifier = e_v
                    break
                  end
                end
              when Class
                if opt_v.is_a?(e_k)
                  modifier = e_v
                end
                end
              break if modifier
            end unless ext_opts.empty?

            # check if it is true or false
            if modf.key?(:then) && opt_v === true
              modifier = modf[:then]
            elsif modf.key?(:else) && opt_v === false
              modifier = modf[:else] == :otherwise ? modf[:otherwise] : modf[:else]
            else
              modifier = modf[:modifier]
            end unless modifier

            k_v = opt_k ? prep_opt_v(opt_k, opt_v, modf) : { }
            modifier = case modifier
                       when Hash
                         modifier.merge(k_v)
                       when Array
                         modifier[1].merge!(k_v) if modifier[1].is_a?(Hash)
                         modifier
                       when String
                         if k_v.empty?
                           [ modifier ]
                         else
                           [ modifier, k_v ]
                         end
                       end

            case modf[:type]
            when :order
              order(modifier[0])
            else
              condition(modifier)
            end
          end
        end
      end

      @opt_v.pop
    end

    def applies?(options, opt_k, opt_v, modf)
      # applies based on :if modifier
      applies_if = true
      if modf.key?(:if)
        case modf[:if]
        when Array
          applies_if = modf[:if].reject { |f| options.key?(f) }.empty?
        else
          applies_if = options.key?(modf[:if])
        end
      end

      # applies based on :unless modifier
      applies_unless = true
      if modf.key?(:unless)
        case modf[:unless]
        when Array
          applies_unless = (modf[:unless] & options.keys).empty?
        else
          applies_unless = !options.key?(modf[:unless])
        end
      end

      # applies based on :nil modifier
      applies_nil = true
      if modf.key?(:nil)
        applies_nil = (opt_v.nil? && modf[:nil] === true) ||
          (!opt_v.nil? && modf[:nil] === false)
      end

      # only applies if all apply modifier is true!
      applies_if && applies_unless && applies_nil
    end

    def opt_v_last
      @opt_v.last
    end

    def prep_opt_v(opt_k, opt_v = :_xxx_default_param_unset, modf = { })
      opt_v = opt_v_last if opt_v == :_xxx_default_param_unset

      case opt_v
      when ::ActiveRecord::Base
        if modf[:polymorphic]
          { "with_#{modf[:polymorphic].to_s}_id".to_sym => opt_v.id,
            "with_#{modf[:polymorphic].to_s}_type".to_sym => opt_v.class.name }
        else
          { opt_k => opt_v.id }
        end
      when Hash
        opt_v.each do |k,v|
          opt_v[k] = prep_opt_v(k, v)
        end
        opt_v
      when Array
        if modf[:format]
          { opt_k => format(modf[:format], *opt_v) }
        elsif modf[:between]
          { "#{opt_k}_from".to_sym => opt_v[0],
            "#{opt_k}_to".to_sym => opt_v[1] }
        elsif modf[:polymorphic]
          types = { }

          # let's group the values by their classes
          opt_v.each do |v|
            if types.key?(v.class.name)
              types[v.class.name] += [ v.id ]
            else
              types[v.class.name] = [ v.id ]
            end
          end

          modi = { }
          for tp_k, tp_v in types
            modi["with_#{modf[:polymorphic].to_s}_#{tp_k}_id".to_sym] = tp_v
            modi["with_#{modf[:polymorphic].to_s}_#{tp_k}_type".to_sym] = tp_k
          end

          modi
        else
          { opt_k => opt_v.collect { |v| prep_opt_v(opt_k, v).values[0] } }
        end
      when Range
        if modf[:between]
          { "#{opt_k}_from".to_sym => opt_v.begin,
            "#{opt_k}_to".to_sym => opt_v.end }
        else
          { opt_k => opt_v }
        end
      else
        if modf[:format]
          { opt_k => format(modf[:format], opt_v) }
        else
          { opt_k => opt_v }
        end
      end
    end
  end
end
