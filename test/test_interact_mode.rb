require 'helper'

class TestInteractMode < Test::Unit::TestCase
  # Assume that irb(1) exists in $PATH on the system for these tests
  def setup
    @exp = Expectr.new("irb", flush_buffer: false, timeout: 1)
    sleep 0.2
  end

  def test_appropriate_flags_are_set
    assert_equal(false, @exp.interact?)
    interact_thread = @exp.interact!

    assert_equal(true, @exp.flush_buffer)
    assert_equal(true, @exp.interact?)
    @exp.flush_buffer = false

    @exp.flush_buffer = false
    @exp.send("quit\n")

    interact_thread.join
  end

  def test_interact_mode
    interact_thread = @exp.interact!
    @exp.flush_buffer = false

    @exp.send("300+21\n")
    @exp.send("quit\n")
    assert_not_nil(@exp.expect(/321/))
    interact_thread.join
  end

  def test_interact_mode_blocking
    interact_thread = Thread.new { @exp.interact!(blocking: true) }

    sleep 0.1 until @exp.interact?
    @exp.flush_buffer = false
    @exp.send("300+21\n")
    @exp.send("quit\n")

    assert_not_nil(@exp.expect(/321/))
    interact_thread.join
  end

  def test_leaving_interact_mode
    interact_thread = @exp.interact!
    @exp.flush_buffer = false

    assert_nothing_raised { @exp.leave! }
    assert_equal(false, @exp.interact?)
    @exp.send("quit\n")
    interact_thread.join
  end
end
