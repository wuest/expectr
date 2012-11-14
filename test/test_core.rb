require 'helper'

class CoreTests < Test::Unit::TestCase
  # For the purpose of testing, we will assume we are working within a POSIX
  # environment.
  def setup
    @exp = Expectr.new("ls /dev", flush_buffer: false, timeout: 1,
                       buffer_size: 4096)
  end

  def test_object_consistency
    assert_equal(false, @exp.flush_buffer)
    assert_equal(1, @exp.timeout)
    assert_equal(4096, @exp.buffer_size)
  end

  # POSIX specifies /dev/console, /dev/null and /dev/tty must exist.
  def test_match_sets_discard
    assert_not_equal(nil, @exp.expect(/null/))
    assert_not_equal('', @exp.discard)
  end

  def test_match_failure
    assert_raises(Timeout::Error) { @exp.expect(/ThisFileShouldNotExist/) }
    assert_nothing_raised { @exp.expect(/ThisFileShouldNotExist/, true) }
  end

  def test_clear_buffer
    sleep 1
    assert_not_equal(@exp.buffer, '')
    @exp.clear_buffer!
    assert_equal('', @exp.buffer)
  end

  def test_garbage_output
    @exp = Expectr.new("dd if=/dev/urandom bs=1024 count=1",
                       flush_buffer:false, timeout: 1, buffer_size: 1024)
    assert_nothing_raised { @exp.expect(/probablyNotThere/, true) }
  end

  def test_pid_set
    assert @exp.pid > 0
  end
end
