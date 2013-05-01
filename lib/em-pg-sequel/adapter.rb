module EM::PG::Sequel
  class Adapter < PG::EM::Client
    DISCONNECT_ERROR_RE = /\Acould not receive data from server/

    self.translate_results = false if respond_to?(:translate_results=)

    # Hash of prepared statements for this connection.  Keys are
    # string names of the server side prepared statement, and values
    # are SQL strings.
    attr_reader(:prepared_statements) if SEQUEL_POSTGRES_USES_PG

    # Raise a Sequel::DatabaseDisconnectError if a PGError is raised and
    # the connection status cannot be determined or it is not OK.
    def check_disconnect_errors
      begin
        yield
      rescue PGError => e
        disconnect = false
        begin
          s = status
        rescue PGError
          disconnect = true
        end
        status_ok = (s == Adapter::CONNECTION_OK)
        disconnect ||= !status_ok
        disconnect ||= e.message =~ DISCONNECT_ERROR_RE
        disconnect ? raise(Sequel.convert_exception_class(e, Sequel::DatabaseDisconnectError)) : raise
      ensure
        block if status_ok && !disconnect
      end
    end

    # Execute the given SQL with this connection.  If a block is given,
    # yield the results, otherwise, return the number of changed rows.
    def execute(sql, args=nil)
      args = args.map{|v| @db.bound_variable_arg(v, self)} if args
      q = check_disconnect_errors{execute_query(sql, args)}
      begin
        block_given? ? yield(q) : q.cmd_tuples
      ensure
        q.clear if q && q.respond_to?(:clear)
      end
    end

    private
    # Return the PGResult object that is returned by executing the given
    # sql and args.
    def execute_query(sql, args)
      @db.log_yield(sql, args){args ? exec(sql, args) : exec(sql) }
    end
  end

  class Database < ::Sequel::Postgres::Database
    set_adapter_scheme :pgsynchrony

    def initialize(opts = {}, &block)
      opts[:pool_class] = ConnectionPool
      super
    end

    def connect(server)
      opts = server_opts(server)
      connection_params = {
        :host => opts[:host],
        :port => opts[:port] || 5432,
        :dbname => opts[:database],
        :user => opts[:user],
        :password => opts[:password],
        :connect_timeout => opts[:connect_timeout] || 20,
        :sslmode => opts[:sslmode]
      }.delete_if { |key, value| blank_object?(value) }
      conn = Adapter.connect(connection_params)
      if encoding = opts[:encoding] || opts[:charset]
        conn.set_client_encoding(encoding)
      end
      conn.instance_variable_set(:@db, self)
      conn.instance_variable_set(:@prepared_statements, {})
      connection_configuration_sqls.each{|sql| conn.execute(sql)}
      conn
    end
  end
end
