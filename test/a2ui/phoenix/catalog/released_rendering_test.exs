defmodule A2UI.Phoenix.Catalog.ReleasedRenderingTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest, only: [render_component: 2]

  alias A2UI.{Component, Surface}
  alias A2UI.Phoenix.Catalog.Standard

  test "Text preserves Markdown when an explicit variant is present" do
    surface = %Surface{
      id: "main",
      protocol_version: :v0_9_1,
      components: %{
        "root" => %Component{
          id: "root",
          type: "Text",
          props: %{"text" => "**important**", "variant" => "h2"}
        }
      }
    }

    html =
      render_component(&Standard.render_component/1,
        id: "root",
        surface: surface,
        depth: 0
      )

    assert html =~ "<strong>important</strong>"
    assert html =~ "a2ui-text-markdown"
  end

  test "List is scrollable on its layout axis and adds no structural gap" do
    surface = %Surface{
      id: "main",
      protocol_version: :v0_9_1,
      components: %{
        "root" => %Component{
          id: "root",
          type: "List",
          props: %{"children" => [], "direction" => "horizontal"}
        }
      }
    }

    html =
      render_component(&Standard.render_component/1,
        id: "root",
        surface: surface,
        depth: 0
      )

    assert html =~ "overflow-x: auto"
    assert html =~ "overflow-y: hidden"
    refute html =~ "gap:"
  end

  test "released Image and Row defaults match the Basic Catalog" do
    surface = %Surface{
      id: "main",
      protocol_version: :v0_9_1,
      components: %{
        "image" => %Component{
          id: "image",
          type: "Image",
          props: %{"url" => "https://example.com/image.png", "description" => "Preview"}
        },
        "root" => %Component{
          id: "root",
          type: "Row",
          props: %{"children" => ["image"]}
        }
      }
    }

    html = render_component(&Standard.render_component/1, id: "root", surface: surface, depth: 0)

    assert html =~ "align-items: stretch"
    refute html =~ "gap:"
    assert html =~ "object-fit: fill"
    assert html =~ "max-width: 256px"
    assert html =~ ~s(alt="Preview")
  end

  test "all released icon forms render instead of falling back" do
    for {name, expected} <- [
          {"play", "hero-play"},
          {"fastForward", "hero-forward"},
          {"volumeOff", "hero-speaker-x-mark"},
          {%{"svgPath" => "M3 12h18"}, "M3 12h18"}
        ] do
      surface = %Surface{
        id: "main",
        protocol_version: :v0_9_1,
        components: %{
          "root" => %Component{id: "root", type: "Icon", props: %{"name" => name}}
        }
      }

      html =
        render_component(&Standard.render_component/1, id: "root", surface: surface, depth: 0)

      assert html =~ expected
      refute html =~ "hero-question-mark-circle"
    end
  end

  test "DateTimeInput resolves and applies min and max" do
    surface = %Surface{
      id: "main",
      protocol_version: :v0_9_1,
      data_model: %{"earliest" => "2026-01-01", "latest" => "2026-12-31"},
      components: %{
        "root" => %Component{
          id: "root",
          type: "DateTimeInput",
          props: %{
            "value" => "2026-07-19",
            "enableDate" => true,
            "min" => %{"path" => "/earliest"},
            "max" => %{"path" => "/latest"}
          }
        }
      }
    }

    html = render_component(&Standard.render_component/1, id: "root", surface: surface, depth: 0)
    assert html =~ ~s(min="2026-01-01")
    assert html =~ ~s(max="2026-12-31")
  end

  test "released leaf spacing is on components and Text inherits color" do
    surface = %Surface{
      id: "main",
      protocol_version: :v0_9_1,
      components: %{
        "root" => %Component{id: "root", type: "Text", props: %{"text" => "Hello"}}
      }
    }

    html = render_component(&Standard.render_component/1, id: "root", surface: surface, depth: 0)
    assert html =~ "a2ui-component m-2"
    refute html =~ "text-zinc-900"
    refute html =~ "dark:text-zinc-50"
  end
end
