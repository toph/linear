require "minitest/autorun"

require "index"

# Some light testing. Mostly just blackboxes it.
class IndexedTest < MiniTest::Test
  BASE_DIR = File.dirname(File.dirname(File.expand_path(__FILE__)))
  TEST_FILE = File.join(BASE_DIR, "files", "sample.txt")
  TEST_LINES = File.readlines(TEST_FILE)

  # Just looking for generate to not fail.
  # The real proof that prepare worked will be when we [].
  def test_generate_succeeds
    Index.generate(TEST_FILE, index_filename)
  end

  # [] is guaranteed to only be called with positive Integers.
  # Basically that means we should test indexes for lines
  # that exist and indexes that are too high.
  def test_index
    Index.generate(TEST_FILE, index_filename)
    index = Index.new(TEST_FILE, index_filename)

    TEST_LINES.size.times do |i|
      assert_equal TEST_LINES[i], index[i]
    end

    assert_nil index[TEST_LINES.size]
    assert_nil index[7000]
    # Make sure random access works too
    assert_equal TEST_LINES[3], index[3]
  end

  def index_filename
    File.join(dir, "#{File.basename(TEST_FILE)}.index")
  end

  def dir
    @dir ||= Dir.mktmpdir("linear")
  end
end
