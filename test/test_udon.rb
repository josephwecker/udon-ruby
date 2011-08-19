require 'helper'
$KCODE='U'

class TestUdon < MiniTest::Unit::TestCase
  def test_blank_documents
    ##############
    assert_equal         [],                    ''.udon
    ##############
    (0..3).each do
      s = randstr(200,"      \t\n\r")
      ##############
      assert_equal       s,                     s.udon.join('')
      ##############
    end
  end

  def test_passthru_documents
    (0..3).each do
      s = randstr(100)
      s.gsub! /^\s*(<\||#|\|)/u, '' # Remove stuff that triggers udon mode
      ##############
      assert_equal       s,                     s.udon.join('')
      ##############
    end
  end

  def test_only_block_comment
    ##############
    assert_equal         '#hi'.udon[0].name,    'comment'
    assert_equal         '#hi'.udon[0].c[0],    'hi'
    assert_equal         '#  hi'.udon[0].c[0],  'hi'
    ##############
  end

  def test_block_comment_indent_level_with_leading
    leading = randstr(200,"      \t\n\r") + "\n"
    comment = <<-COMMENT
      #  line 0
         line 1
        line 2

       line 4

      # comment 2
     COMMENT
    following = randstr(200,"     \t\n\r")
    s = (leading + comment + following)
    r = s.udon
    lines = r[-2].c
    ##############
    assert_instance_of   UdonParser::UNode,     r[-2]
    assert_equal         'comment',             r[-2].name
    assert_equal         'line 0',              lines[0]
    assert_equal         'line 1',              lines[1]
    assert_equal         'line 2',              lines[2]
    assert_equal         "\n",                  lines[3]
    assert_equal         'line 4',              lines[4]
    assert_instance_of   UdonParser::UNode,     r[-1]
    assert_equal         'comment',             r[-1].name
    ##############
  end

  def test_block_comment_in_passthru

  end
end
