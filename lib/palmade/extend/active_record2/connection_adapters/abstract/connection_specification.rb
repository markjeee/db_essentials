module Palmade::DbEssentials::Extend
  module ActiveRecord::Base::ConnectionSpecification
    module ConnectionSpecificationClass
      def speckey
        @config[:_speckey]
      end

      def persist?
        @config[:persist] || false
      end

      def local?
        @config[:_local] || false
      end

      # used to identify this connection as the same one
      # when persisting connections
      def identity
        if speckey.nil? || speckey.empty?
          [ @config[:host], @config[:port], @config[:socket],
            @config[:username], @config[:database] ].collect { |s| s.to_s }.join('-')
        else
          speckey.to_s
        end
      end
    end

    module ClassMethods
      def connection_key
        unless connection_pool.nil?
          connection_pool.spec.speckey
        else
          nil
        end
      end

      def establish_local_connection(spec = nil, &block)
        spec = RAILS_ENV if spec.nil?
        establish_connection(spec, true, &block)
      end

      def remove_local_connection(klass = self)
        remove_connection(klass, true)
      end

      def remove_connection_with_db_essentials(klass = self, local = false)
        connection_handler.remove_connection(klass, local)
      end

      # this extensions adds the following:
      # - support for environment.subdatabase
      #
      # note: sub databases, only inherits first-level configs
      # will not do a deep clone
      def establish_connection_with_db_essentials(spec = nil, local = false, &block)
        # if given a block, we'll just be using this connection
        # temporarily, and will unlock it back as soon as we are done
        if block_given?
          prev_spec = nil
          begin
            prev_spec = remove_connection(self, local)
            establish_connection(spec, local)
            yield
          ensure
            unless prev_spec.nil?
              establish_connection(prev_spec, local)
            else
              remove_connection(self, local)
            end
          end
        else
          case spec
          when nil
            raise ::ActiveRecord::Base::AdapterNotSpecified unless defined? RAILS_ENV
            establish_connection(RAILS_ENV, local)
          when ::ActiveRecord::Base::ConnectionSpecification
            self.connection_handler.establish_connection(name, spec)
          when Symbol, String
            establish_connection(get_configuration(spec), local)
          when Hash
            spec["_local"] = local
            spec = spec_for(spec)
            establish_connection(spec, local)
          else
            raise ArgumentError, "Unsupported spec type (#{spec.class.name}): #{spec}"
          end
        end
      end

      protected

      def spec_for(config)
        # XXX This looks pretty fragile.  Will break if AR changes how it initializes connections and adapters.
        config = config.symbolize_keys
        adapter_method = "#{config[:adapter]}_connection"
        initialize_adapter(config[:adapter])
        ::ActiveRecord::Base::ConnectionSpecification.new(config, adapter_method)
      end

      def initialize_adapter(adapter)
        begin
          require 'rubygems'
          gem "activerecord-#{adapter}-adapter"
          require "active_record/connection_adapters/#{adapter}_adapter"
        rescue LoadError
          begin
            require "active_record/connection_adapters/#{adapter}_adapter"
          rescue LoadError
            raise "Please install the #{adapter} adapter: `gem install activerecord-#{adapter}-adapter` (#{$!})"
          end
        end
      end

      def get_configuration(spec)
        spec = spec.to_s
        if spec[0] == ?.
          env_config = configurations[RAILS_ENV]
          if env_config.include?(spec)
            sub_config = { }

            # inherit parent configurations
            env_config.each do |k,v|
              sub_config[k] = v unless k[0] == ?.
            end

            # attach it's own configurations
            env_config[spec].each do |k,v|
              sub_config[k] = v
            end

            sub_config["_speckey"] = spec
            sub_config
          else
            raise ::ActiveRecord::Base::AdapterNotSpecified, "#{spec} database is not configured"
          end
        else
          if configurations.include?(spec)
            configuration = { }

            configurations[spec].each do |k,v|
              configuration[k] = v unless k[0] == ?.
            end

            configuration["_speckey"] = spec
            configuration
          else
            raise ::ActiveRecord::Base::AdapterNotSpecified, "#{spec} database is not configured"
          end
        end
      end
    end

    def self.included(base)
      base.extend(ClassMethods)

      # use this to run code on the singleton class of ActiveRecord::Base
      class << base
        # class and sub-class specific setting
        attr_accessor :connection_top_level

        alias_method_chain :establish_connection, :db_essentials
        alias_method_chain :remove_connection, :db_essentials
      end
    end
  end
end

# attach ActiveRecord::Base::ConnectionSpecification extensions
ActiveRecord::Base::
  ConnectionSpecification.send(:include,
                               Palmade::DbEssentials::Extend::ActiveRecord::Base::ConnectionSpecification::ConnectionSpecificationClass)

# attach ActiveRecord::Base extensions
ActiveRecord::Base.send(:include,
                        Palmade::DbEssentials::Extend::ActiveRecord::Base::ConnectionSpecification)
