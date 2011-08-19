require 'helper'
$KCODE='U'

class TestUdon < MiniTest::Unit::TestCase
  def test_blank_documents
    assert_equal(''.udon,[])
    (0..3).each do
      s = randstr(200,"      \t\n\r")
      assert_equal(s.udon.join(''),s)
    end
  end

  def test_passthrough_documents
    chars = [[0.10,  " \t"],
             [0.05,  "\n\r"],
             [0.40,  ('a'..'z')],
             [0.15,  ('A'..'Z')],
             [0.15,  ('0'..'9')],
             [0.075, (32..126)],
             [0.05,  (0..255)],
             [0.025, (0..0xffff)]]
    (0..3).each do
      s = randstr(100,chars)
      s.gsub! /^\s*(<\||#|\|)/u, '' # Remove stuff that triggers udon mode
      assert_equal(s.udon.join(''),s)
    end
  end

  def test_block_comments
    #leading = randstr(200,"      \t\n\r")
    #comment = "# hello\na"
    #following = randstr(200,"     \t\n\r")
    #(leading + comment + following).udon_pp
  end
end
