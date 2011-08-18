require 'teststrap'


context 'An udon document' do
  setup { ''.udon }
  context 'that is empty' do
    asserts_topic.equals([])
  end
  context 'with only whitespace' do
    setup {randstr(200," \t\n\r").udon}
    asserts_topic.equals([])
  end
  context 'with a single line indented block comment' do
    setup {(randstr(10,[' '])+"#"+randstr(200)).udon}
    asserts_topic.size(1)
    asserts("has one node with name that"){topic[0].name}.equals('comment')
  end
  context 'with a block comment' do
    setup do <<-UDON.udon
        # c1
          c2
         c3
      UDON
    end
    asserts_topic.size(1)
    context 'has a node' do
      setup {topic[0]}
      asserts(:name).equals('comment')
    end
  end
end
