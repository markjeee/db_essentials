module Palmade::DbEssentials::Extend
  module ActiveRecord::ConnectionAdapters::ConnectionPool
    module ClassMethods
      def new(spec)
        if spec.persist?
          # TODO: Make thread-safe!
          # check if we exists in the global persist list
          # use that if we are there, otherwise, let's add a new one
          id = spec.identity
          if persistent_connections.include?(id)
            pool = persistent_connections[id]
            # just verify, just in case
            pool.verify_active_connections!
            pool
          else
            persistent_connections[id] = super
          end
        else
          super
        end
      end
    end

    # Disconnects all connections in the pool, and clears the pool.
    def disconnect_with_db_essentials!(forreal = false)
      if spec.persist?
        persist!(forreal)
      else
        disconnect_without_db_essentials!
      end
    end

    protected

    def persist!(forreal = false)
      # when persisting, only remove the reserved connections by threads
      @reserved_connections.each do |name,conn|
        checkin conn
      end
      @reserved_connections = { }

      if forreal
        @connections.each do |conn|
          conn.disconnect!
        end
        @connections = [ ]

        # delete ourselves from list of persistent connections
        persistent_connections.delete_if { |k,v| v == self }
      end
    end

    def self.included(base)
      base.extend(ClassMethods)

      # add an cattribute accessor to singleton class,
      # and don't allow modifications
      class << base
        cattr_accessor :persistent_connections, :instance_writer => false
        self.persistent_connections = { }
      end

      base.class_eval do
        alias_method_chain :disconnect!, :db_essentials
      end
    end
  end

  module ActiveRecord::ConnectionAdapters::ConnectionHandler
    def establish_connection_with_db_essentials(name, spec)
      name = "#{name}-#{th_key}" if spec.local?
      establish_connection_without_db_essentials(name, spec)
    end

    # check for localized connection pool first!
    def retrieve_connection_pool_with_db_essentials(klass, use_local = true, for_klass = nil)
      if for_klass.nil?
        for_klass = klass

        # just for cleaning up, let's clean up dead/orphaned local connection first
        drop_dead_local_connections!
      end

      local_name = "#{klass.name}-#{th_key}"

      # let's check, if we have a thread-specific local name specified
      if use_local
        pool = @connection_pools[local_name]
        #warn "Using a local connection #{local_name}" unless pool.nil?
      else
        pool = @connection_pools[klass.name]
      end

      # added to check if this connection has been marked top-level
      # and should not inherit what is above.
      if pool.nil? && !(::ActiveRecord::Base == klass || klass.connection_top_level)
        # let's check if we have a nil, and has exhausted all our options
        pool = retrieve_connection_pool(klass.superclass, use_local, for_klass)
      end

      # back at the top, and still using local,
      # we'll try the global connections now
      if pool.nil? && for_klass == klass && use_local
        pool = retrieve_connection_pool(klass, false)
      end

      pool
    end

    def clear_active_connections_with_db_essentials!
      # let's drop dead or orphaned connections
      drop_dead_local_connections!

      # TODO: make thread-safe
      # let's remove any thread-specific connection here
      diskon = Set.new
      @connection_pools.delete_if do |k, pool|
        if k =~ /\-#{th_key}$/
          diskon.add(pool); true
        else
          false
        end
      end
      disconnect_if_notneeded(diskon)

      clear_active_connections_without_db_essentials!
    end

    # remove connection with support for thread-specifics
    def remove_connection_with_db_essentials(klass, local = false)
      if klass.is_a?(Class)
        remove_connection(klass.name, local)
      else
        if local
          local_name = "#{klass}-#{th_key}"
          remove_connection(local_name, false)
        else
          # TODO: make thread-safe
          pool = @connection_pools.delete(klass)
          if pool
            pool.disconnect! if pool_users(pool).empty?
            pool.spec.config
          else
            nil
          end
        end
      end
    end

    protected

    # return an array of classes still using this pool
    def pool_users(pool)
      @connection_pools.keys.collect { |k| @connection_pools[k] == pool ? k : nil }.compact
    end

    # disconnection a pool if no other is using it
    def disconnect_if_notneeded(diskon)
      unless diskon.empty?
        diskon.each do |pool|
          pool.disconnect! if pool_users(pool).empty?
        end
      end
    end

    # drop local connections for dead threads
    def drop_dead_local_connections!
      # let's get a list of threads that has local connections
      local_keys = @connection_pools.keys.collect { |k| k =~ /(.+)\-(.+)$/ ? $~[2] : nil }.uniq.compact

      # remove all alive threads
      Thread.list.each do |th|
        local_keys.delete(th_key(th)) if th.alive?
      end

      # TODO: thread-safe
      # this part is particularly not thread-safe?!?
      # disconnect and remove already dead threads
      diskon = Set.new
      @connection_pools.delete_if do |k, pool|
        if k =~ /(.+)\-(.+)$/ && local_keys.include?($~[2])
          diskon.add(pool); true
        else
          false
        end
      end
      disconnect_if_notneeded(diskon)

      nil
    end

    def th_key(th = nil)
      (th || Thread.current).object_id.abs.to_s
    end

    def self.included(base)
      base.class_eval do
        alias_method_chain :retrieve_connection_pool, :db_essentials
        alias_method_chain :clear_active_connections!, :db_essentials
        alias_method_chain :remove_connection, :db_essentials
        alias_method_chain :establish_connection, :db_essentials
      end
    end
  end
end

ActiveRecord::ConnectionAdapters::
  ConnectionPool.send(:include,
                      Palmade::DbEssentials::Extend::ActiveRecord::ConnectionAdapters::ConnectionPool)

ActiveRecord::ConnectionAdapters::
  ConnectionHandler.send(:include,
                         Palmade::DbEssentials::Extend::ActiveRecord::ConnectionAdapters::ConnectionHandler)
