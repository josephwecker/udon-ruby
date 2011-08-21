require 'helper'
$KCODE='U'

class TestUdon < MiniTest::Unit::TestCase
  TRIGGER_UDON = /(^\s*(#|\|).*(?=\n)|<\||<:)/umn
  WHITESPACE   = "      \t\n\r"

  def test_blank_documents
    ##############
    assert_equal         [],                    ''.udon
    ##############
    (0..3).each do
      s = randstr(200,WHITESPACE)
      ##############
      assert_equal       s,                     s.udon.join('')
      ##############
    end
  end

  def test_passthru_documents
    (0..3).each do
      s = randstr(100).gsub(TRIGGER_UDON,'')
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
    leading = randstr(200,WHITESPACE) + "\n"
    following = randstr(200,WHITESPACE)
    comment = <<-COMMENT
      #  line 0
         line 1
        line 2

       line 4

      # comment 2
     COMMENT
    r = (leading + comment + following).udon
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
    leading = randstr(200).gsub(TRIGGER_UDON,'') + "\n"
    following = randstr(200).gsub(TRIGGER_UDON,'')
    comment = <<-COMMENT
      # the-comment
      and back to normal
    COMMENT
    r = (leading + comment + following).udon
    # Find the comment
    found_i = nil
    r.each_with_index{|c,i| if c.is_a?(UdonParser::UNode) then found_i=i; break end}
    ##############
    refute_nil           found_i
    assert               found_i < r.size
    assert               found_i > 0
    assert_equal         'comment',             r[found_i].name
    assert_equal         leading,               r[0..(found_i-1)].join('')
    assert_equal         following,             r[(found_i+2)..-1].join('')
    ##############
  end

  def test_simple_node
    r = "asdf\n|the-node\nasdf".udon
    ##############
    assert_instance_of   UdonParser::UNode,     r[1]
    assert_equal         'the-node',            r[1].name
    assert_equal         "asdf\n",              r[0]
    assert_equal         "asdf",                r[2]
    ##############
  end

SCRATCH=<<-SCRATCH

|one         # Sets ipar
 a:b         # no base
   c:d       # no base
  e:f        # no base
      g h i  # sets base to indent

|one blah    # Sets ipar to indent
  asdf       # sets base to indent

# SO: first non-ident non-inline child sets base (or its own ipar)



|asdf
  `howdy fejw ioafj weifj <:oawj:> fa weoi`: kvjjfejiwo
  `howdy fejw ioafj weifj <:oawj:> fa weoi` kvjjfejiwo




SCRATCH

end
