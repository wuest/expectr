require 'helper'

class InteractionTest < Test::Unit::TestCase
  # Assume that bc(1) exists on the system for these tests
  def setup
    @exp = Expectr.new("bc", flush_buffer: false, timeout: 1)
  end

  def test_send_and_expect
    assert_nothing_raised do
      @exp.send("300+21\n")
      @exp.expect("321")
      @exp.puts("quit")
    end
  end

  def test_expect_with_block
    assert_nothing_raised do
      @exp.send("300+21\n")
      @exp.expect("321") { |m| m.nil? ? raise(ArgumentError) : true }
    end

    assert_raises(TimeoutError) do
      @exp.send("300+21\n")
      @exp.expect("xxx") { |m| m.nil? ? raise(ArgumentError) : true }
    end

    assert_raises(ArgumentError) do
      @exp.send("300+21\n")
      @exp.expect("xxx", true) { |m| m.nil? ? raise(ArgumentError) : true }
    end
  end

  def test_send_to_terminated_fails
    @exp.send("quit\n")
    sleep 2
    assert_raises(Expectr::ProcessError) { @exp.send("test\n") }
  end

  def test_interact_sets_appropriate_flags
    [
      Thread.new {
        assert_equal false, @exp.interact?

        sleep 0.5
        @exp.interact!.join
      },
      Thread.new {
        sleep 1
        assert_equal true, @exp.flush_buffer
        assert_equal true, @exp.interact?

        @exp.flush_buffer = false
        @exp.send("quit\n")
      }
    ].each {|x| x.join}
  end

  def test_interact_mode
    [
      Thread.new {
        sleep 0.5
        @exp.interact!.join
      },
      Thread.new {
        sleep 1
        @exp.flush_buffer = false
        @exp.send("300+21\n")
        @exp.send("quit\n")
      }
    ].each {|x| x.join}

    assert_not_nil @exp.expect(/321/)
  end

  def test_leaving_interact_mode
    [
      Thread.new {
        sleep 0.5
        @exp.interact!.join
      },
      Thread.new {
        sleep 1
        @exp.flush_buffer = false
        assert_nothing_raised { @exp.leave! }
        assert_equal false, @exp.interact?
        @exp.send("quit\n")
      }
    ].each {|x| x.join}
  end

  def test_blocking_interact_mode
    [
      Thread.new {
        sleep 0.5
        @exp.interact!(blocking: true)
      },
      Thread.new {
        sleep 1
        @exp.flush_buffer = false
        @exp.send("300+21\n")
        @exp.send("quit\n")
      }
    ].each {|x| x.join}

    assert_not_nil @exp.expect(/321/)
  end

  def test_kill_process
    assert_equal true, @exp.kill!
    assert_equal 0, @exp.pid
    assert_raises(Expectr::ProcessError) { @exp.send("test\n") }
  end
end
