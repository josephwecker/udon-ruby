require 'helper'
$KCODE='U'

class TestUdon < MiniTest::Unit::TestCase
  WHITESPACE   = "      \t\n\r"

  #----------------------------------------------------------------------------
  def test_blank_documents
    assert_equal [], ''.udon
    assert_equal "\n\t  \r\t", "\n\t  \r\t".udon.join('')
    (0..3).each do
      s = randstr(200,WHITESPACE)
      assert_equal s, s.udon.join('')
    end
  end

  #----------------------------------------------------------------------------
  def test_passthru_documents
    assert_equal "random doc\n doing stuff", "random doc\n doing stuff".udon.join('')
    (0..5).each do
      s = udon_safe(randstr(200))
      assert_equal s, s.udon.join('')
    end
  end

  #----------------------------------------------------------------------------
  def test_only_block_comment
    assert_equal '#hi'.udon[0].name,   'comment'
    assert_equal '#hi'.udon[0].c[0],   'hi'
    assert_equal '#  hi'.udon[0].c[0], 'hi'
  end

  #----------------------------------------------------------------------------
  def test_block_comment_indent_level_with_leading
    leading = randstr(200,WHITESPACE)
    following = randstr(200,WHITESPACE)
    comment = <<-COMMENT
      \t
      #  line 0
         line 1
        line 2

       line 4

      # comment 2
     COMMENT
    r = (leading + comment + following).udon
    lines = r[-2].c # second to last child should be the comment
    assert_instance_of UdonParser::UNode, r[-2]
    assert_equal       'comment',         r[-2].name
    assert_equal       'line 0',          lines[0]
    assert_equal       'line 1',          lines[1]
    assert_equal       'line 2',          lines[2]
    assert_equal       "\n",              lines[3]
    assert_equal       'line 4',          lines[4]
    # Last comment sucks up all "following" whitespace as well
    assert_instance_of UdonParser::UNode, r[-1]
    assert_equal       'comment',         r[-1].name
  end

  #----------------------------------------------------------------------------
  def test_block_comment_in_passthru
    leading = udon_safe(randstr(200))
    following = udon_safe(randstr(200))
    comment = <<-COMMENT
      # the-comment
      and back to normal
    COMMENT
    r = (leading + comment + following).udon
    # Find the comment since the random before/after means the position is random
    found_i = nil
    r.each_with_index{|c,i| if c.is_a?(UdonParser::UNode) then found_i=i; break end}

    refute_nil   found_i
    assert       found_i < r.size
    assert       found_i > 0
    assert_equal 'comment', r[found_i].name
    assert_equal leading,   r[0..(found_i-1)].join('')
    assert_equal following, r[(found_i+2)..-1].join('')
  end

  #----------------------------------------------------------------------------
  def test_simple_node
    r = "asdf\n|the-node\nasdf".udon
    assert_instance_of UdonParser::UNode, r[1]
    assert_equal       'the-node',        r[1].name
    assert_equal       "asdf\n",          r[0]
    assert_equal       "asdf",            r[2]
  end

  #----------------------------------------------------------------------------
  def test_node_name_undelimited_cstring
    assert_equal 'hello-there! friend', '|hello-there!\ friend a'.udon[0].name
    # TODO: show various delimitings
    (0..20).each do
      name = rand_undelimited_cstring(50)
      assert_equal name, "|#{name} a".udon[0].name
    end
  end

  #----------------------------------------------------------------------------
  def test_node_name_delimited_cstring
    assert_equal ' (hello) ', '|( (hello) ) a'.udon[0].name
    # TODO: show various delimitings
    (0..20).each do
      name = rand_delimited_cstring(50)
      assert_equal unescaped_cstr(name), "|#{name} a".udon[0].name
    end
  end

  #----------------------------------------------------------------------------
  def test_node_id_after_name
    assert_equal 'my id!', "|this-node[my id!]".udon[0].a['id']
  end

=begin

--------------------------- TODO
---- MISC
 [ ] - Change passthru tests so they replace udon triggers w/ escaped triggers
       instead of removing the line.

---- TOP LEVEL DATA
 [ ] - Lines beginning with `|` or `#` must be escaped
 [ ] - Any internal `|{...` or `!{...` must be escaped by doubling the { to
       pass it through literally

---- BLOCK-COMMENTS

---- BASIC DATA (children)
 [ ] - Rules for top level data apply
 [ ] - Started with a `| `
 [ ] - Leading whitespace for first node is not retained and sets base
 [ ] - If the data is on the same line as the node began, any isolated hash
       marks it wants to retain also need to be escaped or they become EOL
       comments.
 [ ] - Full embeds

---- SPECIAL DATA children
 [ ] - Special Basic `|'` -- Same as basic but no EOL comments and can have
       leading space.
 [ ] - Special String `|"`
   [ ] - Metachars
   [ ] - Full embeds

---- DATA NODES
 [d] - Triggered with '|'
 [d] - (Inline) Name (control-string)
 [ ] - Inline ID (bracketed-string - like control-string but w/ required square delims)
 [ ] - Nextline ID
 [ ] - Inline Tags (control-strings starting with '.')
 [ ] - Nextline Tags
 [ ] - Inline attributes no whitespace values
 [ ] - Inline attributes w/ values w/ whitespaces
 [ ] - Inline EOL comments
 [ ] - 

--------------------------- NOTES
---- EOL COMMENTS
     * Only available on lines that begin w/ `|` or `:` unless it's an
       anonymous (!') pipe.
     * The hash mark must have a space before it

---- BUILT-IN 



---------------------------- SCRATCH
# Normal udon-level comment
|# Application-defined block comment (such as html comments)
!# 

First class data; only embeds allowed, no inline comments, no metacharacters
First class => (document text) == `!'` == `| `
CString => (...) in ident == `!"` well, `!{"  "}`

|something :one two| three
  four

*** Attribute values must escape their pipes if not delimited
*** Allow parenthasese to delimit values w/ whitespaces
*** Attribute values extend to next `\s:`, `|`, or newline, or are delimited by () (balanced inner)
*** To start child text w/ whitespace, escape the first whitespace:
    |blah \   I'm indented quite a bit


 * Make sure attributes can easily be ruby symbols - start with :
   -     ::blahspace:url http://example.com:80:

|node :a1 v1
  :'a 2' v 2
  

|node >|another asdf:2 > bcdg:2


|node normal children
  blah blah blah

|(another-node kajsdf jewifowe) asdf
  normal children blah blah blah

|yet-another-node
  !"child with some metachars \n \t to think about
    but no need to have an ending quote, because that's determined by the
    indent
  !'and another child !{`with an embedded string`}


first class text
|node also first class text
  just with a different baseline
  (at least once it gets to the line above this one)
  and when I want something special I just do an
  embedded !{'something or other'}


!'blah blah blah'

|div.red.ugly.blah[leftcol]
|.blah[heya].torn.(fejwio fjeiwo).jfeiwo.(j fjeiwo fejiofjwe f)
|[geo].trans

|===[hm jfeiwo fei]

|(t > fjeio:[blah=feio], fjeiwo)[13th of id]
  :(something this way) (george the carpenter)

--OR--


|my-awesome-node (The blah and blah)   # Comments allowed because child is inline

command-string:
  NAME, (.)TAGS, (*)ID, ATTRIBUTE-NAMES(:), & (sometimes) ATTRIBUTE-VALUES
  - NOT available for children... children that start with a paren need to escape it(?)
  - no whitespace if no delimiter or escaped spaces (usually single word)
  - value embeds available; must evaluate to a string
  - delimited by () - can contain them also as long as they're balanced
  - preserves whitespace(?)

value-string:
  VALUE-EMBEDS, 


|  -> node (values accumulate)
:  -> attribute (values override)
!  -> directive - inject result
!- -> directive, ignore result
(.)-> text (or, if inline, possibly simple-value)

|{...}
!{...}
!{-...} ignore result
!{'...'}
!{"..."}
!{`...`}

|name[id].tag.tag2

|hello
  I hope this message finds you well, Mr. !{$blah}
  !urlencode

INLINE
|asdf |bcal
  |child of bcal always

|asdf |bcal this
  sentence continues here below

|asdf |bcal but
this is now a sibling (obviously) of |asdf

|house
  :fixtures
    :south 12
    :north 14
  :color
    :summer green  # Comment allowed
    :winter
      white # Comment not allowed - this is part of the text
    :something\ else blah
  simple value
  and some more
  muahaha
  |something
    :strange
      |good[1]
      |good[2]

|house 



INLINES
  * Goes depth-wise  `|a |b |c d` == `<|a <|b <|c d|>|>|>`
  * Carries over to the next line (indented children of `|a |b |c` are children of `|c`



----------------------------

|one         # Sets ipar
 a: b        # no base
   c: d      # no base
  e: f       # no base
      g h i  # sets base to indent

|one blah    # Sets ipar to indent
  asdf       # sets base to indent

# SO: first non-ident non-inline child sets base (or its own ipar)

=end

end
