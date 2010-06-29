module Palmade::DbEssentials
  class DbConnectionManager
    # TODO: Implement connection pools!

    def initialize(ar)
      @ar = ar

      # connection handling mode
      # default: cache (hint: connection pool is not yet implemented)
      @handling_mode = :cache

      # used in implementing the globally cached connections
      @conn_cache = { }
      @conn_cache_mutex = Mutex.new

      # TODO: Implement connection pool, for concurrent access to
      # db adapters
      @conn_pool = nil
    end

    # make a new connection identified by spec
    def make_conn(spec)
      case @handling_mode
      when :cache
        cache_connect(spec)
      when :pool
        # not yet implemented
        nil
      else
        nil
      end
    end

    # close the specified connection
    def close_conn(spec, h_conn, for_real = false)
      case @handling_mode
      when :cache
        # do nothing i think?
      when :pool
        # return the conn back to the pool
      else
        nil
      end
    end

    # called up, when a thread is closing
    def thread_cleanup
      # do nothing, i think?
    end

    def verify_conn!(konn)
      # this is a specific method called for AR adapters
      konn.verify!(verification_timeout)
    end

    def wake_up!(konn)
      konn.wake_up!
    end

    def verification_timeout
      @ar.verification_timeout
    end

    def logger
      @ar.logger
    end

    # WORKS ONLY WITH ACTIVERECORD (DM might have a different approach)
    #
    # this is the method that will *really* make the connection,
    # based on the given spec -- it will return an adapter for use
    def real_connect(spec)
      config = spec.config.reverse_merge(:allow_concurrency => false)
      @ar.send(spec.adapter_method, config)
    end

    # do a cache connect
    # used to create the connections to the database ahead (global cache)
    # see also connection_pool.rb, for an alternative
    def cache_connect(spec)
      spec_key = spec.spec_key
      konn = nil
      unless spec_key.nil?

        # wrap the calls below in a mutex to prevent, multiple threads from
        # updating the conn cache at the same time, causing unpredictable
        # behaviour!
        @conn_cache_mutex.synchronize do
          konn = if @conn_cache.key?(spec_key)
            logger.debug "#{Thread.current} Cached connection: #{spec_key}\n"
            @conn_cache[spec_key]
          else
            logger.debug "#{Thread.current} New connection: #{spec_key}\n"
            @conn_cache[spec_key] = real_connect(spec)
          end
          verify_conn!(konn) unless konn.nil?
          wake_up!(konn)

          konn
        end
      end
      konn
    end
  end
end
