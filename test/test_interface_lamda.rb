require 'helper'

class TestLambdaInterface < Test::Unit::TestCase
  def setup
    buf = ''
    @reader_lambda = ->(buf) {
      ->(str) {
        buf << str
      }
    }.call(buf)

    @writer_lambda = ->(buf) {
      ->() {
        str = buf.capitalize
        buf.clear
        str
      }
    }.call(buf)
  end

  def test_spawn_from_interface
    assert_nothing_raised { exp = Expectr::Lambda.spawn(@reader_lambda, @writer_lambda, flush_buffer: false) }
  end

  def test_spawn_from_expectr
    assert_nothing_raised { exp = Expectr.new('', flush_buffer: false, interface: :lambda, reader: @reader_lambda, writer: @writer_lambda) }
  end

  def test_lambda_produces_output
    exp = Expectr::Lambda.spawn(@reader_lambda, @writer_lambda, flush_buffer: false)
    assert_nothing_raised { exp.send('hello') }
    assert_nothing_raised { exp.expect(/Hello/) }
  end
end
