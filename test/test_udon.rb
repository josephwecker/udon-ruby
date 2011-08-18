require 'helper'

class TestUdon < MiniTest::Unit::TestCase
  def test_blank_documents
    assert_equal(''.udon,[])
    (0..10).each do
      s = randstr(100,"      \t\n\r")
      assert_equal(s.udon.join(''),s)
    end
  end

  def test_passthrough_documents
    leading = randstr(100,"      \t\n\r")
    comment = "# hello\na"
    following = randstr(100,"     \t\n\r")
    (leading + comment + following).udon_pp

    "\n\n  hello\n\n there".udon_pp
  end
end
