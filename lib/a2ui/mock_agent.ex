defmodule A2UI.MockAgent do
  @moduledoc """
  Mock agent for PoC testing.

  Provides sample A2UI message sequences to demonstrate the renderer.
  """

  @doc """
  Sends a sample contact form to the given LiveView process.

  The form includes:
  - A header with title
  - A card containing form fields:
    - Name (text input)
    - Email (text input)
    - Message (textarea)
    - Subscribe checkbox
  - Action buttons (Reset and Submit)

  Messages are sent as `{:a2ui, json_line}` tuples.
  """
  @spec send_sample_form(pid()) :: :ok
  def send_sample_form(pid) do
    # Surface update with components
    send(pid, {:a2ui, surface_update_json()})

    # Data model
    send(pid, {:a2ui, data_model_json()})

    # Begin rendering
    send(pid, {:a2ui, begin_rendering_json()})

    :ok
  end

  defp surface_update_json do
    ~s({"surfaceUpdate":{"surfaceId":"main","components":[) <>
      ~s({"id":"root","component":{"Column":{"children":{"explicitList":["header","form","actions"]}}}},) <>
      ~s({"id":"header","component":{"Text":{"text":{"literalString":"Contact Form"},"usageHint":"h1"}}},) <>
      ~s({"id":"form","component":{"Card":{"child":"form_fields"}}},) <>
      ~s({"id":"form_fields","component":{"Column":{"children":{"explicitList":["name_field","email_field","message_field","subscribe"]}}}},) <>
      ~s({"id":"name_field","component":{"TextField":{"label":{"literalString":"Name"},"text":{"path":"/form/name"},"textFieldType":"shortText"}}},) <>
      ~s({"id":"email_field","component":{"TextField":{"label":{"literalString":"Email"},"text":{"path":"/form/email"},"textFieldType":"shortText"}}},) <>
      ~s({"id":"message_field","component":{"TextField":{"label":{"literalString":"Message"},"text":{"path":"/form/message"},"textFieldType":"longText"}}},) <>
      ~s({"id":"subscribe","component":{"CheckBox":{"label":{"literalString":"Subscribe to updates"},"value":{"path":"/form/subscribe"}}}},) <>
      ~s({"id":"actions","component":{"Row":{"children":{"explicitList":["reset_btn","submit_btn"]},"distribution":"end"}}},) <>
      ~s({"id":"reset_btn","component":{"Button":{"child":"reset_text","primary":false,"action":{"name":"reset_form"}}}},) <>
      ~s({"id":"reset_text","component":{"Text":{"text":{"literalString":"Reset"}}}},) <>
      ~s({"id":"submit_btn","component":{"Button":{"child":"submit_text","primary":true,"action":{"name":"submit_form","context":[{"key":"formData","value":{"path":"/form"}}]}}}},) <>
      ~s({"id":"submit_text","component":{"Text":{"text":{"literalString":"Submit"}}}}) <>
      ~s(]}})
  end

  defp data_model_json do
    ~s({"dataModelUpdate":{"surfaceId":"main","contents":[) <>
      ~s({"key":"form","valueMap":[) <>
      ~s({"key":"name","valueString":""},) <>
      ~s({"key":"email","valueString":""},) <>
      ~s({"key":"message","valueString":""},) <>
      ~s({"key":"subscribe","valueBoolean":false}) <>
      ~s(]}]}})
  end

  defp begin_rendering_json do
    ~s({"beginRendering":{"surfaceId":"main","root":"root","styles":{"font":"Inter","primaryColor":"#4f46e5"}}})
  end

  @doc """
  Sends a sample list with template to demonstrate dynamic rendering.

  The list shows items from a map in the data model using template children.

  For strict v0.8 conformance, the data model is updated via multiple
  `dataModelUpdate` messages targeting paths (rather than using an out-of-schema
  `valueArray`).
  """
  @spec send_sample_list(pid()) :: :ok
  def send_sample_list(pid) do
    surface_update =
      ~s({"surfaceUpdate":{"surfaceId":"list","components":[) <>
        ~s({"id":"root","component":{"Column":{"children":{"explicitList":["title","items_container"]}}}},) <>
        ~s({"id":"title","component":{"Text":{"text":{"literalString":"Product List"},"usageHint":"h2"}}},) <>
        ~s({"id":"items_container","component":{"Column":{"children":{"template":{"dataBinding":"/products","componentId":"product_card"}}}}},) <>
        ~s({"id":"product_card","component":{"Card":{"child":"product_content"}}},) <>
        ~s({"id":"product_content","component":{"Column":{"children":{"explicitList":["product_name","product_price"]}}}},) <>
        ~s({"id":"product_name","component":{"Text":{"text":{"path":"/name"},"usageHint":"h4"}}},) <>
        ~s({"id":"product_price","component":{"Text":{"text":{"path":"/price"},"usageHint":"caption"}}}) <>
        ~s(]}})

    data_updates = [
      ~s({"dataModelUpdate":{"surfaceId":"list","path":"/products/0","contents":[{"key":"name","valueString":"Widget A"},{"key":"price","valueString":"$19.99"}]}}),
      ~s({"dataModelUpdate":{"surfaceId":"list","path":"/products/1","contents":[{"key":"name","valueString":"Widget B"},{"key":"price","valueString":"$29.99"}]}}),
      ~s({"dataModelUpdate":{"surfaceId":"list","path":"/products/2","contents":[{"key":"name","valueString":"Widget C"},{"key":"price","valueString":"$39.99"}]}})
    ]

    begin_rendering = ~s({"beginRendering":{"surfaceId":"list","root":"root"}})

    send(pid, {:a2ui, surface_update})
    Enum.each(data_updates, fn line -> send(pid, {:a2ui, line}) end)
    send(pid, {:a2ui, begin_rendering})

    :ok
  end
end
