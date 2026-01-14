defmodule A2uiLvWeb.DemoLiveTest do
  use A2uiLvWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import LazyHTML

  describe "demo page" do
    test "renders loading state initially", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/demo")

      assert html =~ "A2UI LiveView Renderer Demo"
      assert html =~ "Rendered Surface"
    end

    test "renders surface after beginRendering", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/demo")

      load_form(view)

      html = render(view)
      assert html =~ "Contact Form"
      assert html =~ "Name"
      assert html =~ "Email"
      assert html =~ "Message"
      assert html =~ "Subscribe to updates"
      assert html =~ "Submit"
      assert html =~ "--a2ui-primary-color: #4f46e5"
      assert html =~ "a2ui-button-primary"
    end

    test "renders surface from manual messages", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/demo")

      # Send a simple text component
      send(
        view.pid,
        {:a2ui,
         ~s({"surfaceUpdate":{"surfaceId":"test","components":[{"id":"root","component":{"Text":{"text":{"literalString":"Hello World"},"usageHint":"h1"}}}]}})}
      )

      send(view.pid, {:a2ui, ~s({"beginRendering":{"surfaceId":"test","root":"root"}})})

      html = render(view)
      assert html =~ "Hello World"
    end
  end

  describe "two-way binding" do
    test "updates data model on text input", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/demo")

      load_form(view)

      # Find the name field form and submit a change
      view
      |> form("#a2ui-main-name_field-form", %{
        "a2ui_input" => %{
          "surface_id" => "main",
          "path" => "/form/name",
          "value" => "Alice"
        }
      })
      |> render_change()

      # Check debug panel shows updated data model
      html = render(view)
      assert html =~ "Alice"
    end

    test "updates data model on checkbox toggle", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/demo")

      load_form(view)

      # Toggle the subscribe checkbox - send the event directly to avoid form complexity
      render_change(view, "a2ui:toggle", %{
        "a2ui_input" => %{
          "surface_id" => "main",
          "path" => "/form/subscribe",
          "value" => "true"
        }
      })

      # Get the socket state to verify the data model was updated
      # The data model should now show subscribe: true
      # Check that the checkbox is now checked in the re-rendered form
      html = render(view)
      assert html =~ "checked"
    end
  end

  describe "button actions" do
    test "button click triggers action and updates last_action", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/demo")

      load_form(view)

      # First fill in some form data
      view
      |> form("#a2ui-main-name_field-form", %{
        "a2ui_input" => %{
          "surface_id" => "main",
          "path" => "/form/name",
          "value" => "Bob"
        }
      })
      |> render_change()

      # Click the submit button
      view
      |> element("button[phx-value-component-id='submit_btn']")
      |> render_click()

      # Check that last action was captured
      html = render(view)
      assert html =~ "Last Action"
      assert html =~ "submit_form"
      assert html =~ "formData"
    end

    test "reset button triggers reset_form action", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/demo")

      load_form(view)

      # Click the reset button
      view
      |> element("button[phx-value-component-id='reset_btn']")
      |> render_click()

      html = render(view)
      assert html =~ "reset_form"
    end
  end

  describe "multiple surfaces" do
    test "renders multiple surfaces independently", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/demo")

      load_form(view)

      # Send messages for a second surface
      send(
        view.pid,
        {:a2ui,
         ~s({"surfaceUpdate":{"surfaceId":"second","components":[{"id":"root","component":{"Text":{"text":{"literalString":"Second Surface"}}}}]}})}
      )

      send(view.pid, {:a2ui, ~s({"beginRendering":{"surfaceId":"second","root":"root"}})})

      sync(view)

      html = render(view)
      # Should have both the main form and the second surface
      assert html =~ "Contact Form"
      assert html =~ "Second Surface"
    end
  end

  describe "surfaceUpdate weight" do
    test "applies weight as flex-grow for Row children", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/demo")

      send(
        view.pid,
        {:a2ui,
         ~s({"surfaceUpdate":{"surfaceId":"weighted","components":[) <>
           ~s({"id":"root","component":{"Row":{"children":{"explicitList":["a","b"]}}}},) <>
           ~s({"id":"a","weight":1,"component":{"Text":{"text":{"literalString":"A"}}}},) <>
           ~s({"id":"b","weight":2,"component":{"Text":{"text":{"literalString":"B"}}}}) <>
           ~s(]}})}
      )

      send(view.pid, {:a2ui, ~s({"beginRendering":{"surfaceId":"weighted","root":"root"}})})

      html = render(view)
      assert html =~ "flex: 2 1 0%"
    end
  end

  describe "deleteSurface" do
    test "removes surface on deleteSurface message", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/demo")

      load_form(view)

      html = render(view)
      assert html =~ "Contact Form"

      # Delete the surface
      send(view.pid, {:a2ui, ~s({"deleteSurface":{"surfaceId":"main"}})})

      html = render(view)
      refute html =~ "Contact Form"
    end
  end

  describe "template expansion" do
    test "renders template instances with unique DOM ids" do
      pid = self()
      A2UI.MockAgent.send_sample_list(pid)

      lines =
        for _ <- 1..5 do
          receive do
            {:a2ui, line} -> line
          end
        end

      surface =
        Enum.reduce(lines, A2UI.Surface.new("list"), fn line, acc ->
          case A2UI.Parser.parse_line(line) do
            {:surface_update, msg} -> A2UI.Surface.apply_message(acc, msg)
            {:data_model_update, msg} -> A2UI.Surface.apply_message(acc, msg)
            {:begin_rendering, msg} -> A2UI.Surface.apply_message(acc, msg)
            _ -> acc
          end
        end)

      html = render_component(&A2UI.Renderer.surface/1, surface: surface)
      document = from_fragment(html)

      all_ids =
        document
        |> query("div")
        |> attribute("id")
        |> Enum.filter(&is_binary/1)

      ids =
        all_ids
        |> Enum.filter(&String.starts_with?(&1, "a2ui-list-product_card-"))

      assert length(ids) == 3
      assert Enum.uniq(ids) == ids
    end
  end

  defp load_form(view) do
    A2UI.MockAgent.send_sample_form(view.pid)
    sync(view)
    :ok
  end

  defp sync(view) do
    _ = :sys.get_state(view.pid)
    :ok
  end
end
