require 'spec_helper'
require 'em-synchrony'
require 'em-synchrony/fiber_iterator'

describe EM::PG::Sequel do
  DELAY = 1
  QUERY = "select pg_sleep(#{DELAY})"

  let(:url) { DB_URL }
  let(:size) { 1 }
  let(:db) { Sequel.connect(url, max_connection: size, db_logger: Logger.new(nil)) }
  let(:test) { db[:test] }

  after do
    db.disconnect
  end

  it "sets connection pool" do
    db.instance_variable_get(:@pool).must_be_instance_of(EM::PG::Sequel::DatabaseConnectionPool)
  end

  describe "table does not exist" do
    it "should raise exception" do
      EM.synchrony do
        proc { test.all }.must_raise Sequel::DatabaseError

        EM.stop
      end
    end
  end

  describe "table exists" do
    before do
      EM.synchrony do
        db.create_table!(:test) do
          text :name
          integer :value, index: true
        end

        EM.stop
      end
    end

    after do
      EM.synchrony do
        db.drop_table?(:test)

        EM.stop
      end
    end

    it "should connect and execute query" do
      EM.synchrony do
        test.insert name: "andrew", value: 42
        test.where(name: "andrew").first[:value].must_equal 42

        EM.stop
      end
    end

    describe "pool size is exceeded" do
      let(:size) { 1 }

      it "should queue requests" do
        EM.synchrony do
          start = Time.now.to_f

          res = []
          EM::Synchrony::FiberIterator.new([1,2], 1).each do |t|
            res << db[QUERY].all
          end
          (Time.now.to_f - start.to_f).must_be_within_delta DELAY * 2, DELAY * 2 * 0.15
          res.size.must_equal 2

          EM.stop
        end
      end
    end

    describe "pool size is enough" do
      let(:size) { 2 }

      it "should parallelize requests" do
        EM.synchrony do
          start = Time.now.to_f

          res = []
          EM::Synchrony::FiberIterator.new([1,2], 2).each do |t|
            res << db[QUERY].all
          end

          (Time.now.to_f - start.to_f).must_be_within_delta DELAY, DELAY * 0.30
          res.size.must_equal 2

          EM.stop
        end
      end
    end
  end
end
