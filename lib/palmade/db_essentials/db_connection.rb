module Palmade::DbEssentials
  class DbConnection
    def initialize(dbm, ukey = nil)
      @dbm = dbm
      @ukey ||= generate_random_chars(16)
      @tkey = "dbc_#{@ukey}"
      @conn_mutex = Mutex.new
    end

    def tkey
      @tkey
    end

    # uses connection stack
    def with_connection(spec, &block)
      establish_connection(spec, nil, &block)
    end

    # set the connection for this klass, for this thread
    def establish_connection(conn_key, spec, th = nil, &block)
      # either uses a stack, or change the thread specific connection
      if block_given?
        push_connection(conn_key, spec, th)
        ret = yield
        pop_connection(th)
        ret
      elsif in_stack?
        raise "Can not modify thread-based connection when in stack"
      else
        use_connection(conn_key, spec, th)
      end
    end

    def remove_connection(th = nil)
      if in_stack?
        raise "Can not remove thread-based connection when in stack"
      else
        de_conn(th)
      end
    end

    def make_or_verify_conn(conn = nil, th = nil)
      conn ||= self.conn(th)
      conn.unless_nil? do

        # wrap the calls below in a global mutex, to prevent multiple threads
        # from checking and updating at the same time (causing unpredictable situation)
        @conn_mutex.synchronize do
          if conn.h_conn.nil?
            make_conn(conn)
          else
            @dbm.verify_conn!(conn.h_conn)
            conn.h_conn
          end
        end
      end
    end

    def h_conn(th = nil)
      make_or_verify_conn(nil, th)
    end

    def conn(th = nil)
      tconf(th).connections.last
    end

    def conn_key(th = nil)
      conn = self.conn(th)
      conn.unless_nil? { conn.conn_key }
    end

    def tconf(th = nil)
      t(th)[tkey] || t(th)[tkey] = new_conf
    end

    def has_valid_connection?(th = nil)
      tconf(th).connections.size > 0
    end

    def in_stack?(th = nil)
      tconf(th).stack_size > 0
    end

    protected

    # push a new connection, that will be used by the given block
    def push_connection(conn_key, spec, th = nil)
      conns = tconf(th).connections
      n_conn = new_conn(conn_key, spec)
      conns.push(n_conn)
      tconf(th).stack_size += 1
      conns.last
    end

    # pop the latest connection, and revert back to the old setup
    def pop_connection(th = nil)
      conns = tconf(th).connections
      prev_conn = conns.pop
      close_conn(prev_conn) unless prev_conn.nil?
      tconf(th).stack_size -= 1 if tconf(th).stack_size > 0
      conns.last
    end

    # replace the thread-specific connection
    def use_connection(conn_key, spec, th = nil)
      # remove connection first
      de_conn(th)

      conns = tconf(th).connections
      n_conn = new_conn(conn_key, spec)
      conns.unshift(n_conn)
      n_conn
    end

    def de_conn(th = nil)
      prev_conn = nil
      conns = tconf(th).connections
      if conns.size > 0
        prev_conn = conns.shift
        close_conn(prev_conn) unless prev_conn.nil?
      end
      prev_conn
    end

    def t(th = nil)
      th.nil? ? Thread.current : th
    end

    def new_conf
      o = OpenStruct.new
      o.connections = Array.new
      o.stack_size = 0
      o.dbc = self
      o
    end

    def new_conn(conn_key, spec)
      o = OpenStruct.new
      o.spec = spec
      o.conn_key = conn_key
      o.h_conn = nil
      o
    end

    # this one actually makes the connection
    # (a) can either work with a globally cached persistent connection
    # (b) or, work with connection pool
    def make_conn(conn)
      conn.h_conn = @dbm.make_conn(conn.spec)
    end

    # if a connection is removed or replaced,
    # call this method, to do whatever is needed to clean out
    # conn object
    def close_conn(conn)
      @dbm.close_conn(conn.spec, conn.h_conn)
      conn.h_conn = nil
    end

    # this method is called when a Thread is about to die
    # or when an controller->action is about to close
    def thread_cleanup(th)
      tc = tconf(th)
      tc.connections.each { |conn| close_conn(conn) }
      tc.connections.clear
      tc.stack_size = 0
      tc.dbc = nil

      true
    end

    def remove_tconf(th = nil)
      t(th)[tkey] = nil
    end
  end
end
