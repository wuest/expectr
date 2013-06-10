require 'helper'

class TestCoreInteraction < Test::Unit::TestCase
  # Assume that irb(1) exists in $PATH on the system for these tests
  def setup
    @exp = Expectr.new("irb", flush_buffer: false, timeout: 1)
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

  def test_send_and_expect
    assert_nothing_raised do
      @exp.send("300+21\n")
      @exp.expect("321")
      @exp.puts("quit")
    end
  end

  def test_send_to_terminated_fails
    @exp.send("quit\n")
    sleep 2
    assert_raises(Expectr::ProcessError) { @exp.send("test\n") }
  end

  def test_winsize_is_set
    assert_not_equal([0, 0], @exp.winsize)
  end
end
