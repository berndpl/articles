import Testing

struct HTMLToMarkdownConverterTests {
    @Test
    func convertsCommonArticleElements() {
        let html = """
        <article>
          <h2>Subhead</h2>
          <p>A <strong>bold</strong> link to <a href="https://example.com">Example</a>.</p>
          <ul><li>One</li><li>Two</li></ul>
          <blockquote>Quoted text</blockquote>
          <pre><code>let x = 1</code></pre>
        </article>
        """

        let markdown = HTMLToMarkdownConverter.convert(html, title: "Main Title")

        #expect(markdown.contains("# Main Title"))
        #expect(markdown.contains("## Subhead"))
        #expect(markdown.contains("**bold**"))
        #expect(markdown.contains("[Example](https://example.com)"))
        #expect(markdown.contains("- One"))
        #expect(markdown.contains("> Quoted text"))
        #expect(markdown.contains("```"))
        #expect(markdown.contains("let x = 1"))
    }
}
