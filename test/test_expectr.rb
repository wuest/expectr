require 'helper'

class TestExpectr < Test::Unit::TestCase
	def setup
		@exp = Expectr.new "ls /bin", :flush_buffer => false, :timeout => 2, :buffer_size => 4096
	end

	def test_execution
		assert_equal @exp.flush_buffer, false
		assert_equal @exp.timeout, 2
		assert_equal @exp.buffer_size, 4096
	end

	def test_match
		assert_not_equal @exp.expect(/sh/), nil
		assert_not_equal @exp.discard, ''
	end

	def test_match_failure
		assert_raises(Timeout::Error) { @exp.expect /ThisFileShouldNotExist/ }
		assert_nothing_raised { @exp.expect /ThisFileShouldNotExist/, true }
	end

	def test_send
		exp = Expectr.new "bc", :flush_buffer => false
		exp.send "20+301\n"
		exp.expect /321/
	end

	def test_clear_buffer
		sleep 1
		assert_not_equal @exp.buffer, ''
		@exp.clear_buffer
		assert_equal @exp.buffer, ''
	end

	def test_pid_set
		assert @exp.pid > 0
	end

	def test_interact
		unless RUBY_VERSION =~ /1.8/
			exp = Expectr.new "bc", :flush_buffer => false
			[
				Thread.new {
					sleep 1
					exp.interact
				},
				Thread.new {
					sleep 2
					assert_equal exp.flush_buffer, true
					exp.flush_buffer = false
					exp.send "300+21\n"
					exp.send "quit\n"
				}
			].each {|x| x.join}

			assert_not_nil exp.expect /321/
		end
	end
end
