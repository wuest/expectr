require 'helper'

class TestAdoptInterface < Test::Unit::TestCase
  def setup
    @pty_stdout,@pty_stdin,@pty_pid = PTY.spawn("/bin/ls")
  end

  def test_spawn_from_interface
    assert_nothing_raised { exp = Expectr::Adopt.spawn(@pty_stdout, @pty_stdin, @pty_pid, flush_buffer: false) }
  end

  def test_spawn_from_expectr
    assert_nothing_raised { exp = Expectr.new('', flush_buffer: false, interface: :adopt, stdin: @pty_stdin, stdout: @pty_stdout, pid: @pty_pid) }
  end
end
