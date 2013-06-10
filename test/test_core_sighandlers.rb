require 'helper'

class TestCoreSighandlers < Test::Unit::TestCase
  def setup
    @exp = Expectr.new("irb", flush_buffer: false, timeout: 1)
  end

  def teardown
    @exp.kill! if @exp.pid > 0
  end

  def test_change_winsize
    winsize = $stdout.winsize
    [
      Thread.new {
        sleep 0.5
        @exp.interact!.join
      },
      Thread.new {
        sleep 1
        @exp.flush_buffer = false
        assert_nothing_raised do
          $stdout.winsize = [10, 10]
        end
        sleep 0.1
        assert_equal([10, 10], @exp.winsize)
        @exp.puts("quit")
      }
    ].each { |x| x.join }

    $stdout.winsize = winsize
  end

  def test_kill_process
    assert_equal(true, @exp.kill!)
    sleep 0.5
    assert_equal(0, @exp.pid)
    assert_raises(Expectr::ProcessError) { @exp.send("test\n") }
  end
end
