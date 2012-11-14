require 'helper'

class InitializationTests < Test::Unit::TestCase
  def test_spawn_with_file
    assert_nothing_raised { exp = Expectr.new(File.new("/bin/ls"), flush_buffer: false) }
  end

  def test_spawn_with_string
    assert_nothing_raised { exp = Expectr.new(File.new("/bin/ls"), flush_buffer: false) }
  end

  # lib/expectr.rb's permissions should hopefully be set to 0644
  def test_spawn_failures
    assert_raises(Errno::ENOENT) { exp = Expectr.new("lib/ThisFileShouldNotExist", flush_buffer: false) }
    assert_raises(Errno::EACCES) { exp = Expectr.new("lib/expectr.rb", flush_buffer: false) }
  end
end
