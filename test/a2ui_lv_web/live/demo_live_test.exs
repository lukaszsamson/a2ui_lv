defmodule A2uiLvWeb.DemoLiveTest do
  use A2uiLvWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  describe "demo page" do
    test "renders loading state initially", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/demo")

      assert html =~ "A2UI LiveView Renderer Demo"
      assert html =~ "Loading surface"
    end

    test "renders surface after beginRendering", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/demo")

      # Wait for the mock agent to send messages
      # The mount sends :load_demo which triggers MockAgent.send_sample_form
      # Give it a moment to process
      Process.sleep(50)

      html = render(view)
      assert html =~ "Contact Form"
      assert html =~ "Name"
      assert html =~ "Email"
      assert html =~ "Message"
      assert html =~ "Subscribe to updates"
      assert html =~ "Submit"
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

      # Wait for surface to render
      Process.sleep(50)

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

      # Wait for surface to render
      Process.sleep(50)

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

      # Wait for surface to render
      Process.sleep(50)

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

      # Wait for surface to render
      Process.sleep(50)

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

      # Send messages for a second surface
      send(
        view.pid,
        {:a2ui,
         ~s({"surfaceUpdate":{"surfaceId":"second","components":[{"id":"root","component":{"Text":{"text":{"literalString":"Second Surface"}}}}]}})}
      )

      send(view.pid, {:a2ui, ~s({"beginRendering":{"surfaceId":"second","root":"root"}})})

      # Wait for processing
      Process.sleep(50)

      html = render(view)
      # Should have both the main form and the second surface
      assert html =~ "Contact Form"
      assert html =~ "Second Surface"
    end
  end

  describe "deleteSurface" do
    test "removes surface on deleteSurface message", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/demo")

      # Wait for main surface to render
      Process.sleep(50)

      html = render(view)
      assert html =~ "Contact Form"

      # Delete the surface
      send(view.pid, {:a2ui, ~s({"deleteSurface":{"surfaceId":"main"}})})

      html = render(view)
      refute html =~ "Contact Form"
    end
  end
end
