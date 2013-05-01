module EM::PG::Sequel
  class FiberConnectionPool
    attr_reader :available

    def initialize(opts, &blk)
      @available = []
      @pending = []
      @acquire_blk = blk

      @disconnected_class = opts[:disconnect_class]

      opts[:size].times do
        @available.push @acquire_blk.call
      end
    end

    def execute
      conn = acquire
      yield conn
    rescue => e
      conn = @acquire_blk.call if @disconnected_class && @disconnected_class === e
      raise
    ensure
      release(conn)
    end

    def acquire
      f = Fiber.current
      if conn = @available.pop
        conn
      else
        @pending << f
        Fiber.yield
      end
    end

    def release(conn)
      if job = @pending.shift
        EM.next_tick { job.resume conn }
      else
        @available << conn
      end
    end
  end

  class DatabaseConnectionPool < ::Sequel::ConnectionPool
    DEFAULT_SIZE = 4
    attr_accessor :pool

    def initialize(db, opts = {})
      super
      size = opts[:max_connections] || DEFAULT_SIZE
      @pool = FiberConnectionPool.new(size: size, disconnect_class: ::Sequel::DatabaseConnectionError) do
        make_new(DEFAULT_SERVER)
      end
    end

    def size
      @pool.available.size
    end

    def hold(server = nil, &blk)
      @pool.execute(&blk)
    end

    def disconnect(server = nil)
      @pool.available.each { |conn| db.disconnect_connection(conn) }
      @pool.available.clear
    end
  end

  ConnectionPool = DatabaseConnectionPool
end
