defmodule A2UI.Phoenix.Catalog.Standard.HelpersTest do
  use ExUnit.Case, async: true

  alias A2UI.Phoenix.Catalog.Standard.Helpers

  describe "render_markdown/1" do
    test "renders nil as empty string" do
      assert Helpers.render_markdown(nil) == ""
    end

    test "renders empty string as empty string" do
      assert Helpers.render_markdown("") == ""
    end

    test "renders plain text" do
      result = Helpers.render_markdown("Hello world")
      assert result =~ "Hello world"
      assert result =~ "<p>"
    end

    test "renders bold text" do
      result = Helpers.render_markdown("This is **bold** text")
      assert result =~ "<strong>bold</strong>"
    end

    test "renders italic text" do
      result = Helpers.render_markdown("This is *italic* text")
      assert result =~ "<em>italic</em>"
    end

    test "renders inline code" do
      result = Helpers.render_markdown("Use `code` here")
      assert result =~ "<code"
      assert result =~ "code"
    end

    test "renders unordered lists" do
      result = Helpers.render_markdown("- Item 1\n- Item 2")
      assert result =~ "<ul>"
      assert result =~ "<li>"
      assert result =~ "Item 1"
    end

    test "renders ordered lists" do
      result = Helpers.render_markdown("1. First\n2. Second")
      assert result =~ "<ol>"
      assert result =~ "<li>"
      assert result =~ "First"
    end

    test "renders blockquotes" do
      result = Helpers.render_markdown("> This is a quote")
      assert result =~ "<blockquote>"
      assert result =~ "This is a quote"
    end

    test "renders headings" do
      result = Helpers.render_markdown("# Heading 1")
      assert result =~ "<h1>"
      assert result =~ "Heading 1"

      result2 = Helpers.render_markdown("## Heading 2")
      assert result2 =~ "<h2>"
    end

    test "strips img tags" do
      result = Helpers.render_markdown("![alt](http://example.com/img.png)")
      refute result =~ "<img"
      refute result =~ "img.png"
    end

    test "strips links but keeps text" do
      result = Helpers.render_markdown("[Link Text](http://example.com)")
      refute result =~ "<a"
      refute result =~ "href"
      assert result =~ "Link Text"
    end

    test "strips dangerous HTML tags" do
      result = Helpers.render_markdown("<script>alert('xss')</script>")
      refute result =~ "<script"
      refute result =~ "alert"
    end

    test "strips iframe tags" do
      result = Helpers.render_markdown("<iframe src=\"http://evil.com\"></iframe>")
      refute result =~ "<iframe"
      refute result =~ "evil.com"
    end

    test "keeps safe HTML tags" do
      # These are markdown-generated, not raw HTML
      result = Helpers.render_markdown("**bold** and *italic*")
      assert result =~ "<strong>"
      assert result =~ "<em>"
    end

    test "handles non-string input by converting to string" do
      result = Helpers.render_markdown(123)
      assert result == "123"
    end
  end
end
