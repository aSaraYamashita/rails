# frozen_string_literal: true

require "cases/helper"
require "models/person"
require "action_dispatch"

module ActiveRecord
  class DatabaseSelectorTest < ActiveRecord::TestCase
    setup do
      @session_store = {}
      @session = ActiveRecord::Middleware::DatabaseSelector::Resolver::Session.new(@session_store)
    end

    def test_empty_session
      assert_equal Time.at(0), @session.last_write_timestamp
    end

    def test_writing_the_session_timestamps
      assert @session.update_last_write_timestamp

      session2 = ActiveRecord::Middleware::DatabaseSelector::Resolver::Session.new(@session_store)
      assert_equal @session.last_write_timestamp, session2.last_write_timestamp
    end

    def test_writing_session_time_changes
      assert @session.update_last_write_timestamp

      before = @session.last_write_timestamp
      sleep(0.1)

      assert @session.update_last_write_timestamp
      assert_not_equal before, @session.last_write_timestamp
    end

    def test_read_from_replicas
      @session_store[:last_write] = ActiveRecord::Middleware::DatabaseSelector::Resolver::Session.convert_time_to_timestamp(Time.now - 5.seconds)

      resolver = ActiveRecord::Middleware::DatabaseSelector::Resolver.new(@session)

      called = false
      resolver.read do
        called = true
        assert ActiveRecord::Base.connected_to?(role: :reading)
      end
      assert called
    end

    def test_read_from_primary
      @session_store[:last_write] = ActiveRecord::Middleware::DatabaseSelector::Resolver::Session.convert_time_to_timestamp(Time.now)

      resolver = ActiveRecord::Middleware::DatabaseSelector::Resolver.new(@session)

      called = false
      resolver.read do
        called = true
        assert ActiveRecord::Base.connected_to?(role: :writing)
      end
      assert called
    end

    def test_the_middleware_chooses_writing_role_with_POST_request
      middleware = ActiveRecord::Middleware::DatabaseSelector.new(lambda { |env|
        assert ActiveRecord::Base.connected_to?(role: :writing)
        [200, {}, ["body"]]
      })
      assert_equal [200, {}, ["body"]], middleware.call("REQUEST_METHOD" => "POST")
    end

    def test_the_middleware_chooses_reading_role_with_GET_request
      middleware = ActiveRecord::Middleware::DatabaseSelector.new(lambda { |env|
        assert ActiveRecord::Base.connected_to?(role: :reading)
        [200, {}, ["body"]]
      })
      assert_equal [200, {}, ["body"]], middleware.call("REQUEST_METHOD" => "GET")
    end
  end
end