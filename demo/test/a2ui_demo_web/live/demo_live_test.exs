defmodule A2UIDemoWeb.DemoLiveTest do
  use A2UIDemoWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import LazyHTML

  describe "demo page" do
    test "redirects to basic scenario by default", %{conn: conn} do
      {:error, {:live_redirect, %{to: "/demo?scenario=basic"}}} = live(conn, "/demo")
    end

    test "renders basic scenario with form", %{conn: conn} do
      {:ok, view, html} = live(conn, "/demo?scenario=basic")

      assert html =~ "A2UI v0.8 Communication Scenarios"
      assert html =~ "Basic Form"

      # Wait for form to load
      sync(view)
      html = render(view)
      assert html =~ "Contact Form"
      assert html =~ "Name"
      assert html =~ "Email"
    end

    test "renders surface from manual messages", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/demo?scenario=basic")

      # Send a simple text component to a new surface
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

  describe "scenario navigation" do
    test "switches between scenarios", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/demo?scenario=basic")

      # Navigate to dynamic scenario
      view |> element("button", "Dynamic Updates") |> render_click()
      html = render(view)
      assert html =~ "Counter Demo"
      assert html =~ "userAction"

      # Navigate to multi_surface scenario
      view |> element("button", "Multiple Surfaces") |> render_click()
      html = render(view)
      assert html =~ "Surface 1"
      assert html =~ "Surface 2"
    end

    test "template list scenario loads products", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/demo?scenario=template_list")

      sync(view)
      html = render(view)
      assert html =~ "Product List"
      assert html =~ "Widget A"
      assert html =~ "Widget B"
      assert html =~ "Widget C"
    end
  end

  describe "two-way binding" do
    test "updates data model on text input", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/demo?scenario=basic")

      sync(view)

      # Find the name field form and submit a change
      view
      |> form("#a2ui-basic-name_field-form", %{
        "a2ui_input" => %{
          "surface_id" => "basic",
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
      {:ok, view, _html} = live(conn, "/demo?scenario=basic")

      sync(view)

      # Toggle the subscribe checkbox
      render_change(view, "a2ui:toggle", %{
        "a2ui_input" => %{
          "surface_id" => "basic",
          "path" => "/form/subscribe",
          "value" => "true"
        }
      })

      html = render(view)
      assert html =~ "checked"
    end
  end

  describe "button actions" do
    test "button click triggers action and updates last_action", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/demo?scenario=basic")

      sync(view)

      # First fill in some form data
      view
      |> form("#a2ui-basic-name_field-form", %{
        "a2ui_input" => %{
          "surface_id" => "basic",
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
      assert html =~ "Last userAction"
      assert html =~ "submit_form"
      assert html =~ "formData"
    end

    test "reset button triggers reset_form action", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/demo?scenario=basic")

      sync(view)

      view
      |> element("button[phx-value-component-id='reset_btn']")
      |> render_click()

      html = render(view)
      assert html =~ "reset_form"
    end
  end

  describe "dynamic updates" do
    test "counter buttons send userAction and update data model", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/demo?scenario=dynamic")

      wait_for_surfaces(view)

      # Verify the counter UI is rendered
      html = render(view)
      assert html =~ "Counter Demo"

      # Click increment button
      view
      |> element("button[phx-value-component-id='inc_btn']")
      |> render_click()

      # Verify the userAction was captured
      html = render(view)
      assert html =~ "Last userAction"
      assert html =~ "increment"

      # Wait for server response and verify data model update
      Process.sleep(200)
      wait_for_surfaces(view)
      state = :sys.get_state(view.pid)
      surface = state.socket.assigns.a2ui_surfaces["dynamic"]
      assert surface.data_model["counter"] == 1
    end
  end

  describe "multiple surfaces" do
    test "renders multiple surfaces independently", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/demo?scenario=multi_surface")

      sync(view)
      html = render(view)

      assert html =~ "Surface 1: Counter"
      assert html =~ "Surface 2: Status"
      assert html =~ "42"
      assert html =~ "Online"
    end

    test "add surface creates new surface", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/demo?scenario=multi_surface")

      sync(view)

      # Click add surface button
      view |> element("button", "+ Add Surface") |> render_click()

      html = render(view)
      assert html =~ "New Surface"
      assert html =~ "Created at"
    end
  end

  describe "surfaceUpdate weight" do
    test "applies weight as flex-grow for Row children", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/demo?scenario=basic")

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
      {:ok, view, _html} = live(conn, "/demo?scenario=delete_surface")

      sync(view)
      html = render(view)
      assert html =~ "Surface 1"
      assert html =~ "Surface 2"
      assert html =~ "Surface 3"

      # Delete surface 1
      send(view.pid, {:a2ui, ~s({"deleteSurface":{"surfaceId":"deletable-1"}})})

      html = render(view)
      refute html =~ "deletable-1"
      assert html =~ "deletable-2"
      assert html =~ "deletable-3"
    end

    test "delete button sends deleteSurface message", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/demo?scenario=delete_surface")

      sync(view)

      # Click delete on first surface
      view
      |> element("button[phx-value-surface-id='deletable-1']", "Delete")
      |> render_click()

      html = render(view)
      refute html =~ "deletable-1"
    end
  end

  describe "error handling" do
    test "shows error on invalid JSON", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/demo?scenario=error_handling")

      sync(view)

      # Trigger parse error
      view |> element("button", "Trigger Parse Error") |> render_click()

      html = render(view)
      assert html =~ "Last Error"
      assert html =~ "parse_error"
      assert html =~ "JSON decode"
    end

    test "shows error on unknown component", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/demo?scenario=error_handling")

      sync(view)

      # Trigger unknown component error
      view |> element("button", "Unknown Component") |> render_click()

      html = render(view)
      assert html =~ "Last Error"
      assert html =~ "unknown_component"
      assert html =~ "UnknownWidget"
    end
  end

  describe "template expansion" do
    test "renders template instances with unique DOM ids" do
      pid = self()
      A2UIDemo.Demo.MockAgent.send_sample_list(pid)

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

      html = render_component(&A2UI.Phoenix.Renderer.surface/1, surface: surface)
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

  describe "streaming scenario" do
    test "progressively renders components", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/demo?scenario=streaming")

      # Wait for all components to stream in (8 more messages at 400ms each = ~3200ms)
      Process.sleep(4000)

      html = render(view)
      assert html =~ "Streaming Demo"
      assert html =~ "First card loaded!"
      assert html =~ "Second card loaded!"
      assert html =~ "All done!"
    end
  end

  describe "data binding scenario" do
    test "shows all binding modes", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/demo?scenario=data_binding")

      sync(view)
      html = render(view)

      assert html =~ "Data Binding Modes"
      assert html =~ "Literal only:"
      assert html =~ "Static text (no binding)"
      assert html =~ "Path only:"
      assert html =~ "Value from data model"
      assert html =~ "Two-way binding:"
      assert html =~ "Edit me!"
    end

    test "two-way binding updates display", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/demo?scenario=data_binding")

      sync(view)

      # Type in the input field
      render_change(view, "a2ui:input", %{
        "a2ui_input" => %{
          "surface_id" => "binding",
          "path" => "/user_input",
          "value" => "New value!"
        }
      })

      html = render(view)
      # Should appear both in the input and in the display text
      assert html =~ "New value!"
    end
  end

  defp sync(view) do
    _ = :sys.get_state(view.pid)
    :ok
  end

  # Wait for surfaces to be loaded (handles async message processing)
  defp wait_for_surfaces(view, max_attempts \\ 20) do
    Enum.reduce_while(1..max_attempts, nil, fn _, _ ->
      Process.sleep(50)
      state = :sys.get_state(view.pid)

      if map_size(state.socket.assigns.a2ui_surfaces) > 0 do
        {:halt, :ok}
      else
        {:cont, nil}
      end
    end)
  end
end
