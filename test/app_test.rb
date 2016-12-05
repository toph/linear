require "minitest/autorun"
require "rack/test"

require "app"

class AppTest < MiniTest::Test
  include Rack::Test::Methods

  class FakeIndex
    def [](index)
      return nil if index >= 1
      "line1"
    end
  end

  def test_line_exists
    get "/line/0"
    assert last_response.ok?
    assert_equal last_response.body, "line1"
  end

  def test_line_too_far
    get "/line/1"
    assert_equal 413, last_response.status
  end

  def test_line_not_integer
    get "/line/a"
    assert_equal 400, last_response.status
  end

  def test_line_negative
    get "/line/-1"
    assert_equal 400, last_response.status
  end

  def app
    App.new { FakeIndex.new }
  end
end
