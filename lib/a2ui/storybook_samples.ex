defmodule A2UI.StorybookSamples do
  @moduledoc """
  Sample A2UI message sequences for the component storybook.

  Provides examples of all 18 standard catalog components in various configurations.
  """

  @doc """
  Returns a list of {category, title, surface_id, messages} tuples.
  Each tuple contains the A2UI JSONL messages to render a component example.
  """
  def all_samples do
    [
      # Layout Components
      {"Layout", "Column - Basic", "column-basic", column_basic()},
      {"Layout", "Column - Distributions", "column-dist", column_distributions()},
      {"Layout", "Row - Basic", "row-basic", row_basic()},
      {"Layout", "Row - Alignments", "row-align", row_alignments()},
      {"Layout", "Card", "card-basic", card_basic()},
      {"Layout", "List - Vertical", "list-vert", list_vertical()},
      {"Layout", "List - Horizontal", "list-horiz", list_horizontal()},

      # Display Components
      {"Display", "Text - Headings", "text-headings", text_headings()},
      {"Display", "Text - Body & Caption", "text-body", text_body()},
      {"Display", "Divider", "divider", divider()},
      {"Display", "Icon - Common", "icon-common", icon_common()},
      {"Display", "Icon - All Standard", "icon-all", icon_all()},
      {"Display", "Image - Fit Modes", "image-fit", image_fit()},
      {"Display", "Image - Usage Hints", "image-hints", image_usage_hints()},

      # Media Components
      {"Media", "AudioPlayer", "audio", audio_player()},
      {"Media", "Video", "video", video_player()},

      # Interactive Components
      {"Interactive", "Button - Primary & Secondary", "button", button_variants()},
      {"Interactive", "TextField - Types", "textfield", text_field_types()},
      {"Interactive", "TextField - Validation", "textfield-val", text_field_validation()},
      {"Interactive", "CheckBox", "checkbox", checkbox()},
      {"Interactive", "Slider", "slider", slider()},
      {"Interactive", "DateTimeInput", "datetime", datetime_input()},
      {"Interactive", "MultipleChoice - Single", "choice-single", multiple_choice_single()},
      {"Interactive", "MultipleChoice - Multiple", "choice-multi", multiple_choice_multi()},

      # Container Components
      {"Container", "Tabs", "tabs", tabs()},
      {"Container", "Modal", "modal", modal()},

      # Advanced Examples
      {"Advanced", "Data Binding", "binding", data_binding_example()},
      {"Advanced", "Template List", "template", template_list()},
      {"Advanced", "Weight (flex-grow)", "weight", weight_example()},
      {"Advanced", "Nested Layout", "nested", nested_layout()}
    ]
  end

  @doc "Sends all samples for a given surface_id to the LiveView process"
  def send_sample(pid, surface_id) do
    case Enum.find(all_samples(), fn {_, _, sid, _} -> sid == surface_id end) do
      {_, _, _, messages} ->
        Enum.each(messages, fn msg -> send(pid, {:a2ui, msg}) end)
        :ok

      nil ->
        {:error, :not_found}
    end
  end

  # ============================================
  # Layout Components
  # ============================================

  defp column_basic do
    [
      ~s({"surfaceUpdate":{"surfaceId":"column-basic","components":[
        {"id":"root","component":{"Column":{"children":{"explicitList":["t1","t2","t3"]}}}},
        {"id":"t1","component":{"Text":{"text":{"literalString":"First item"}}}},
        {"id":"t2","component":{"Text":{"text":{"literalString":"Second item"}}}},
        {"id":"t3","component":{"Text":{"text":{"literalString":"Third item"}}}}
      ]}}),
      ~s({"beginRendering":{"surfaceId":"column-basic","root":"root"}})
    ]
  end

  defp column_distributions do
    # Simplified sample: Row of 4 columns, each showing a different distribution
    # Uses tall colored boxes to clearly demonstrate item positioning
    [
      ~S|{"surfaceUpdate":{"surfaceId":"column-dist","components":[{"id":"root","component":{"Row":{"children":{"explicitList":["c1","c2","c3","c4"]},"distribution":"spaceEvenly"}}},{"id":"c1","component":{"Column":{"children":{"explicitList":["l1","box1"]},"alignment":"center"}}},{"id":"c2","component":{"Column":{"children":{"explicitList":["l2","box2"]},"alignment":"center"}}},{"id":"c3","component":{"Column":{"children":{"explicitList":["l3","box3"]},"alignment":"center"}}},{"id":"c4","component":{"Column":{"children":{"explicitList":["l4","box4"]},"alignment":"center"}}},{"id":"l1","component":{"Text":{"text":{"literalString":"start"},"usageHint":"caption"}}},{"id":"l2","component":{"Text":{"text":{"literalString":"center"},"usageHint":"caption"}}},{"id":"l3","component":{"Text":{"text":{"literalString":"end"},"usageHint":"caption"}}},{"id":"l4","component":{"Text":{"text":{"literalString":"spaceBetween"},"usageHint":"caption"}}},{"id":"box1","component":{"Card":{"child":"inner1"}}},{"id":"box2","component":{"Card":{"child":"inner2"}}},{"id":"box3","component":{"Card":{"child":"inner3"}}},{"id":"box4","component":{"Card":{"child":"inner4"}}},{"id":"inner1","component":{"Column":{"children":{"explicitList":["i1a","i1b"]},"distribution":"start","minHeight":"150px"}}},{"id":"inner2","component":{"Column":{"children":{"explicitList":["i2a","i2b"]},"distribution":"center","minHeight":"150px"}}},{"id":"inner3","component":{"Column":{"children":{"explicitList":["i3a","i3b"]},"distribution":"end","minHeight":"150px"}}},{"id":"inner4","component":{"Column":{"children":{"explicitList":["i4a","i4b"]},"distribution":"spaceBetween","minHeight":"150px"}}},{"id":"i1a","component":{"Text":{"text":{"literalString":"Top"}}}},{"id":"i1b","component":{"Text":{"text":{"literalString":"Item"}}}},{"id":"i2a","component":{"Text":{"text":{"literalString":"Top"}}}},{"id":"i2b","component":{"Text":{"text":{"literalString":"Item"}}}},{"id":"i3a","component":{"Text":{"text":{"literalString":"Top"}}}},{"id":"i3b","component":{"Text":{"text":{"literalString":"Item"}}}},{"id":"i4a","component":{"Text":{"text":{"literalString":"Top"}}}},{"id":"i4b","component":{"Text":{"text":{"literalString":"Item"}}}}]}}|,
      ~s({"beginRendering":{"surfaceId":"column-dist","root":"root"}})
    ]
  end

  defp row_basic do
    [
      ~s({"surfaceUpdate":{"surfaceId":"row-basic","components":[
        {"id":"root","component":{"Row":{"children":{"explicitList":["i1","t1","spacer","b1"]}}}},
        {"id":"i1","component":{"Icon":{"name":{"literalString":"person"}}}},
        {"id":"t1","component":{"Text":{"text":{"literalString":"John Doe"}}}},
        {"id":"spacer","component":{"Text":{"text":{"literalString":""}}}},
        {"id":"b1","component":{"Button":{"child":"bt1","primary":true}}},
        {"id":"bt1","component":{"Text":{"text":{"literalString":"Edit"}}}}
      ]}}),
      ~s({"beginRendering":{"surfaceId":"row-basic","root":"root"}})
    ]
  end

  defp row_alignments do
    [
      ~s({"surfaceUpdate":{"surfaceId":"row-align","components":[
        {"id":"root","component":{"Column":{"children":{"explicitList":["r1","r2","r3","r4"]}}}},
        {"id":"r1","component":{"Row":{"children":{"explicitList":["l1","box1"]},"alignment":"start"}}},
        {"id":"r2","component":{"Row":{"children":{"explicitList":["l2","box2"]},"alignment":"center"}}},
        {"id":"r3","component":{"Row":{"children":{"explicitList":["l3","box3"]},"alignment":"end"}}},
        {"id":"r4","component":{"Row":{"children":{"explicitList":["l4","box4"]},"alignment":"stretch"}}},
        {"id":"l1","component":{"Text":{"text":{"literalString":"start"},"usageHint":"caption"}}},
        {"id":"l2","component":{"Text":{"text":{"literalString":"center"},"usageHint":"caption"}}},
        {"id":"l3","component":{"Text":{"text":{"literalString":"end"},"usageHint":"caption"}}},
        {"id":"l4","component":{"Text":{"text":{"literalString":"stretch"},"usageHint":"caption"}}},
        {"id":"box1","component":{"Card":{"child":"c1"}}},{"id":"c1","component":{"Text":{"text":{"literalString":"Card"}}}},
        {"id":"box2","component":{"Card":{"child":"c2"}}},{"id":"c2","component":{"Text":{"text":{"literalString":"Card"}}}},
        {"id":"box3","component":{"Card":{"child":"c3"}}},{"id":"c3","component":{"Text":{"text":{"literalString":"Card"}}}},
        {"id":"box4","component":{"Card":{"child":"c4"}}},{"id":"c4","component":{"Text":{"text":{"literalString":"Card"}}}}
      ]}}),
      ~s({"beginRendering":{"surfaceId":"row-align","root":"root"}})
    ]
  end

  defp card_basic do
    [
      ~s({"surfaceUpdate":{"surfaceId":"card-basic","components":[
        {"id":"root","component":{"Card":{"child":"content"}}},
        {"id":"content","component":{"Column":{"children":{"explicitList":["title","desc","action"]}}}},
        {"id":"title","component":{"Text":{"text":{"literalString":"Card Title"},"usageHint":"h3"}}},
        {"id":"desc","component":{"Text":{"text":{"literalString":"This is a card component with some content inside. Cards provide visual grouping and elevation."}}}},
        {"id":"action","component":{"Button":{"child":"btn-text","primary":true}}},
        {"id":"btn-text","component":{"Text":{"text":{"literalString":"Action"}}}}
      ]}}),
      ~s({"beginRendering":{"surfaceId":"card-basic","root":"root"}})
    ]
  end

  defp list_vertical do
    [
      ~s({"surfaceUpdate":{"surfaceId":"list-vert","components":[
        {"id":"root","component":{"List":{"children":{"explicitList":["i1","i2","i3"]},"direction":"vertical","alignment":"stretch"}}},
        {"id":"i1","component":{"Card":{"child":"c1"}}},{"id":"c1","component":{"Text":{"text":{"literalString":"List Item 1"}}}},
        {"id":"i2","component":{"Card":{"child":"c2"}}},{"id":"c2","component":{"Text":{"text":{"literalString":"List Item 2"}}}},
        {"id":"i3","component":{"Card":{"child":"c3"}}},{"id":"c3","component":{"Text":{"text":{"literalString":"List Item 3"}}}}
      ]}}),
      ~s({"beginRendering":{"surfaceId":"list-vert","root":"root"}})
    ]
  end

  defp list_horizontal do
    [
      ~s({"surfaceUpdate":{"surfaceId":"list-horiz","components":[
        {"id":"root","component":{"List":{"children":{"explicitList":["i1","i2","i3"]},"direction":"horizontal","alignment":"center"}}},
        {"id":"i1","component":{"Card":{"child":"c1"}}},{"id":"c1","component":{"Text":{"text":{"literalString":"Item 1"}}}},
        {"id":"i2","component":{"Card":{"child":"c2"}}},{"id":"c2","component":{"Text":{"text":{"literalString":"Item 2"}}}},
        {"id":"i3","component":{"Card":{"child":"c3"}}},{"id":"c3","component":{"Text":{"text":{"literalString":"Item 3"}}}}
      ]}}),
      ~s({"beginRendering":{"surfaceId":"list-horiz","root":"root"}})
    ]
  end

  # ============================================
  # Display Components
  # ============================================

  defp text_headings do
    [
      ~s|{"surfaceUpdate":{"surfaceId":"text-headings","components":[
        {"id":"root","component":{"Column":{"children":{"explicitList":["h1","h2","h3","h4","h5"]}}}},
        {"id":"h1","component":{"Text":{"text":{"literalString":"Heading 1 (h1)"},"usageHint":"h1"}}},
        {"id":"h2","component":{"Text":{"text":{"literalString":"Heading 2 (h2)"},"usageHint":"h2"}}},
        {"id":"h3","component":{"Text":{"text":{"literalString":"Heading 3 (h3)"},"usageHint":"h3"}}},
        {"id":"h4","component":{"Text":{"text":{"literalString":"Heading 4 (h4)"},"usageHint":"h4"}}},
        {"id":"h5","component":{"Text":{"text":{"literalString":"Heading 5 (h5)"},"usageHint":"h5"}}}
      ]}}|,
      ~s({"beginRendering":{"surfaceId":"text-headings","root":"root"}})
    ]
  end

  defp text_body do
    [
      ~s({"surfaceUpdate":{"surfaceId":"text-body","components":[
        {"id":"root","component":{"Column":{"children":{"explicitList":["body","caption"]}}}},
        {"id":"body","component":{"Text":{"text":{"literalString":"This is body text. It is used for regular paragraph content and descriptions."},"usageHint":"body"}}},
        {"id":"caption","component":{"Text":{"text":{"literalString":"This is caption text, typically used for labels or secondary information."},"usageHint":"caption"}}}
      ]}}),
      ~s({"beginRendering":{"surfaceId":"text-body","root":"root"}})
    ]
  end

  defp divider do
    [
      ~s({"surfaceUpdate":{"surfaceId":"divider","components":[
        {"id":"root","component":{"Column":{"children":{"explicitList":["t1","d1","t2","row"]}}}},
        {"id":"t1","component":{"Text":{"text":{"literalString":"Content above horizontal divider"}}}},
        {"id":"d1","component":{"Divider":{"axis":"horizontal"}}},
        {"id":"t2","component":{"Text":{"text":{"literalString":"Content below horizontal divider"}}}},
        {"id":"row","component":{"Row":{"children":{"explicitList":["left","d2","right"]},"alignment":"stretch"}}},
        {"id":"left","component":{"Text":{"text":{"literalString":"Left"}}}},
        {"id":"d2","component":{"Divider":{"axis":"vertical"}}},
        {"id":"right","component":{"Text":{"text":{"literalString":"Right"}}}}
      ]}}),
      ~s({"beginRendering":{"surfaceId":"divider","root":"root"}})
    ]
  end

  defp icon_common do
    [
      ~s({"surfaceUpdate":{"surfaceId":"icon-common","components":[
        {"id":"root","component":{"Column":{"children":{"explicitList":["row1","row2","row3"]}}}},
        {"id":"row1","component":{"Row":{"children":{"explicitList":["i1","i2","i3","i4","i5","i6"]},"distribution":"start"}}},
        {"id":"row2","component":{"Row":{"children":{"explicitList":["i7","i8","i9","i10","i11","i12"]},"distribution":"start"}}},
        {"id":"row3","component":{"Row":{"children":{"explicitList":["i13","i14","i15","i16","i17","i18"]},"distribution":"start"}}},
        {"id":"i1","component":{"Icon":{"name":{"literalString":"home"}}}},
        {"id":"i2","component":{"Icon":{"name":{"literalString":"settings"}}}},
        {"id":"i3","component":{"Icon":{"name":{"literalString":"person"}}}},
        {"id":"i4","component":{"Icon":{"name":{"literalString":"search"}}}},
        {"id":"i5","component":{"Icon":{"name":{"literalString":"mail"}}}},
        {"id":"i6","component":{"Icon":{"name":{"literalString":"notifications"}}}},
        {"id":"i7","component":{"Icon":{"name":{"literalString":"favorite"}}}},
        {"id":"i8","component":{"Icon":{"name":{"literalString":"star"}}}},
        {"id":"i9","component":{"Icon":{"name":{"literalString":"check"}}}},
        {"id":"i10","component":{"Icon":{"name":{"literalString":"close"}}}},
        {"id":"i11","component":{"Icon":{"name":{"literalString":"add"}}}},
        {"id":"i12","component":{"Icon":{"name":{"literalString":"delete"}}}},
        {"id":"i13","component":{"Icon":{"name":{"literalString":"edit"}}}},
        {"id":"i14","component":{"Icon":{"name":{"literalString":"share"}}}},
        {"id":"i15","component":{"Icon":{"name":{"literalString":"download"}}}},
        {"id":"i16","component":{"Icon":{"name":{"literalString":"upload"}}}},
        {"id":"i17","component":{"Icon":{"name":{"literalString":"refresh"}}}},
        {"id":"i18","component":{"Icon":{"name":{"literalString":"info"}}}}
      ]}}),
      ~s({"beginRendering":{"surfaceId":"icon-common","root":"root"}})
    ]
  end

  defp icon_all do
    # Show a curated selection of icons with labels
    [
      ~s({"surfaceUpdate":{"surfaceId":"icon-all","components":[
        {"id":"root","component":{"Column":{"children":{"explicitList":["row1","row2","row3","row4","row5"]}}}},
        {"id":"row1","component":{"Row":{"children":{"explicitList":["g1","g2","g3","g4","g5","g6","g7","g8"]},"distribution":"start"}}},
        {"id":"row2","component":{"Row":{"children":{"explicitList":["g9","g10","g11","g12","g13","g14","g15","g16"]},"distribution":"start"}}},
        {"id":"row3","component":{"Row":{"children":{"explicitList":["g17","g18","g19","g20","g21","g22","g23","g24"]},"distribution":"start"}}},
        {"id":"row4","component":{"Row":{"children":{"explicitList":["g25","g26","g27","g28","g29","g30","g31","g32"]},"distribution":"start"}}},
        {"id":"row5","component":{"Row":{"children":{"explicitList":["g33","g34","g35","g36","g37","g38","g39","g40"]},"distribution":"start"}}},
        {"id":"g1","component":{"Column":{"children":{"explicitList":["i1","l1"]},"alignment":"center"}}},{"id":"i1","component":{"Icon":{"name":{"literalString":"accountCircle"}}}},{"id":"l1","component":{"Text":{"text":{"literalString":"accountCircle"},"usageHint":"caption"}}},
        {"id":"g2","component":{"Column":{"children":{"explicitList":["i2","l2"]},"alignment":"center"}}},{"id":"i2","component":{"Icon":{"name":{"literalString":"add"}}}},{"id":"l2","component":{"Text":{"text":{"literalString":"add"},"usageHint":"caption"}}},
        {"id":"g3","component":{"Column":{"children":{"explicitList":["i3","l3"]},"alignment":"center"}}},{"id":"i3","component":{"Icon":{"name":{"literalString":"arrowBack"}}}},{"id":"l3","component":{"Text":{"text":{"literalString":"arrowBack"},"usageHint":"caption"}}},
        {"id":"g4","component":{"Column":{"children":{"explicitList":["i4","l4"]},"alignment":"center"}}},{"id":"i4","component":{"Icon":{"name":{"literalString":"arrowForward"}}}},{"id":"l4","component":{"Text":{"text":{"literalString":"arrowForward"},"usageHint":"caption"}}},
        {"id":"g5","component":{"Column":{"children":{"explicitList":["i5","l5"]},"alignment":"center"}}},{"id":"i5","component":{"Icon":{"name":{"literalString":"attachFile"}}}},{"id":"l5","component":{"Text":{"text":{"literalString":"attachFile"},"usageHint":"caption"}}},
        {"id":"g6","component":{"Column":{"children":{"explicitList":["i6","l6"]},"alignment":"center"}}},{"id":"i6","component":{"Icon":{"name":{"literalString":"calendarToday"}}}},{"id":"l6","component":{"Text":{"text":{"literalString":"calendarToday"},"usageHint":"caption"}}},
        {"id":"g7","component":{"Column":{"children":{"explicitList":["i7","l7"]},"alignment":"center"}}},{"id":"i7","component":{"Icon":{"name":{"literalString":"call"}}}},{"id":"l7","component":{"Text":{"text":{"literalString":"call"},"usageHint":"caption"}}},
        {"id":"g8","component":{"Column":{"children":{"explicitList":["i8","l8"]},"alignment":"center"}}},{"id":"i8","component":{"Icon":{"name":{"literalString":"camera"}}}},{"id":"l8","component":{"Text":{"text":{"literalString":"camera"},"usageHint":"caption"}}},
        {"id":"g9","component":{"Column":{"children":{"explicitList":["i9","l9"]},"alignment":"center"}}},{"id":"i9","component":{"Icon":{"name":{"literalString":"check"}}}},{"id":"l9","component":{"Text":{"text":{"literalString":"check"},"usageHint":"caption"}}},
        {"id":"g10","component":{"Column":{"children":{"explicitList":["i10","l10"]},"alignment":"center"}}},{"id":"i10","component":{"Icon":{"name":{"literalString":"close"}}}},{"id":"l10","component":{"Text":{"text":{"literalString":"close"},"usageHint":"caption"}}},
        {"id":"g11","component":{"Column":{"children":{"explicitList":["i11","l11"]},"alignment":"center"}}},{"id":"i11","component":{"Icon":{"name":{"literalString":"delete"}}}},{"id":"l11","component":{"Text":{"text":{"literalString":"delete"},"usageHint":"caption"}}},
        {"id":"g12","component":{"Column":{"children":{"explicitList":["i12","l12"]},"alignment":"center"}}},{"id":"i12","component":{"Icon":{"name":{"literalString":"download"}}}},{"id":"l12","component":{"Text":{"text":{"literalString":"download"},"usageHint":"caption"}}},
        {"id":"g13","component":{"Column":{"children":{"explicitList":["i13","l13"]},"alignment":"center"}}},{"id":"i13","component":{"Icon":{"name":{"literalString":"edit"}}}},{"id":"l13","component":{"Text":{"text":{"literalString":"edit"},"usageHint":"caption"}}},
        {"id":"g14","component":{"Column":{"children":{"explicitList":["i14","l14"]},"alignment":"center"}}},{"id":"i14","component":{"Icon":{"name":{"literalString":"error"}}}},{"id":"l14","component":{"Text":{"text":{"literalString":"error"},"usageHint":"caption"}}},
        {"id":"g15","component":{"Column":{"children":{"explicitList":["i15","l15"]},"alignment":"center"}}},{"id":"i15","component":{"Icon":{"name":{"literalString":"favorite"}}}},{"id":"l15","component":{"Text":{"text":{"literalString":"favorite"},"usageHint":"caption"}}},
        {"id":"g16","component":{"Column":{"children":{"explicitList":["i16","l16"]},"alignment":"center"}}},{"id":"i16","component":{"Icon":{"name":{"literalString":"folder"}}}},{"id":"l16","component":{"Text":{"text":{"literalString":"folder"},"usageHint":"caption"}}},
        {"id":"g17","component":{"Column":{"children":{"explicitList":["i17","l17"]},"alignment":"center"}}},{"id":"i17","component":{"Icon":{"name":{"literalString":"help"}}}},{"id":"l17","component":{"Text":{"text":{"literalString":"help"},"usageHint":"caption"}}},
        {"id":"g18","component":{"Column":{"children":{"explicitList":["i18","l18"]},"alignment":"center"}}},{"id":"i18","component":{"Icon":{"name":{"literalString":"home"}}}},{"id":"l18","component":{"Text":{"text":{"literalString":"home"},"usageHint":"caption"}}},
        {"id":"g19","component":{"Column":{"children":{"explicitList":["i19","l19"]},"alignment":"center"}}},{"id":"i19","component":{"Icon":{"name":{"literalString":"info"}}}},{"id":"l19","component":{"Text":{"text":{"literalString":"info"},"usageHint":"caption"}}},
        {"id":"g20","component":{"Column":{"children":{"explicitList":["i20","l20"]},"alignment":"center"}}},{"id":"i20","component":{"Icon":{"name":{"literalString":"lock"}}}},{"id":"l20","component":{"Text":{"text":{"literalString":"lock"},"usageHint":"caption"}}},
        {"id":"g21","component":{"Column":{"children":{"explicitList":["i21","l21"]},"alignment":"center"}}},{"id":"i21","component":{"Icon":{"name":{"literalString":"lockOpen"}}}},{"id":"l21","component":{"Text":{"text":{"literalString":"lockOpen"},"usageHint":"caption"}}},
        {"id":"g22","component":{"Column":{"children":{"explicitList":["i22","l22"]},"alignment":"center"}}},{"id":"i22","component":{"Icon":{"name":{"literalString":"mail"}}}},{"id":"l22","component":{"Text":{"text":{"literalString":"mail"},"usageHint":"caption"}}},
        {"id":"g23","component":{"Column":{"children":{"explicitList":["i23","l23"]},"alignment":"center"}}},{"id":"i23","component":{"Icon":{"name":{"literalString":"menu"}}}},{"id":"l23","component":{"Text":{"text":{"literalString":"menu"},"usageHint":"caption"}}},
        {"id":"g24","component":{"Column":{"children":{"explicitList":["i24","l24"]},"alignment":"center"}}},{"id":"i24","component":{"Icon":{"name":{"literalString":"notifications"}}}},{"id":"l24","component":{"Text":{"text":{"literalString":"notifications"},"usageHint":"caption"}}},
        {"id":"g25","component":{"Column":{"children":{"explicitList":["i25","l25"]},"alignment":"center"}}},{"id":"i25","component":{"Icon":{"name":{"literalString":"person"}}}},{"id":"l25","component":{"Text":{"text":{"literalString":"person"},"usageHint":"caption"}}},
        {"id":"g26","component":{"Column":{"children":{"explicitList":["i26","l26"]},"alignment":"center"}}},{"id":"i26","component":{"Icon":{"name":{"literalString":"phone"}}}},{"id":"l26","component":{"Text":{"text":{"literalString":"phone"},"usageHint":"caption"}}},
        {"id":"g27","component":{"Column":{"children":{"explicitList":["i27","l27"]},"alignment":"center"}}},{"id":"i27","component":{"Icon":{"name":{"literalString":"photo"}}}},{"id":"l27","component":{"Text":{"text":{"literalString":"photo"},"usageHint":"caption"}}},
        {"id":"g28","component":{"Column":{"children":{"explicitList":["i28","l28"]},"alignment":"center"}}},{"id":"i28","component":{"Icon":{"name":{"literalString":"refresh"}}}},{"id":"l28","component":{"Text":{"text":{"literalString":"refresh"},"usageHint":"caption"}}},
        {"id":"g29","component":{"Column":{"children":{"explicitList":["i29","l29"]},"alignment":"center"}}},{"id":"i29","component":{"Icon":{"name":{"literalString":"search"}}}},{"id":"l29","component":{"Text":{"text":{"literalString":"search"},"usageHint":"caption"}}},
        {"id":"g30","component":{"Column":{"children":{"explicitList":["i30","l30"]},"alignment":"center"}}},{"id":"i30","component":{"Icon":{"name":{"literalString":"send"}}}},{"id":"l30","component":{"Text":{"text":{"literalString":"send"},"usageHint":"caption"}}},
        {"id":"g31","component":{"Column":{"children":{"explicitList":["i31","l31"]},"alignment":"center"}}},{"id":"i31","component":{"Icon":{"name":{"literalString":"settings"}}}},{"id":"l31","component":{"Text":{"text":{"literalString":"settings"},"usageHint":"caption"}}},
        {"id":"g32","component":{"Column":{"children":{"explicitList":["i32","l32"]},"alignment":"center"}}},{"id":"i32","component":{"Icon":{"name":{"literalString":"share"}}}},{"id":"l32","component":{"Text":{"text":{"literalString":"share"},"usageHint":"caption"}}},
        {"id":"g33","component":{"Column":{"children":{"explicitList":["i33","l33"]},"alignment":"center"}}},{"id":"i33","component":{"Icon":{"name":{"literalString":"star"}}}},{"id":"l33","component":{"Text":{"text":{"literalString":"star"},"usageHint":"caption"}}},
        {"id":"g34","component":{"Column":{"children":{"explicitList":["i34","l34"]},"alignment":"center"}}},{"id":"i34","component":{"Icon":{"name":{"literalString":"upload"}}}},{"id":"l34","component":{"Text":{"text":{"literalString":"upload"},"usageHint":"caption"}}},
        {"id":"g35","component":{"Column":{"children":{"explicitList":["i35","l35"]},"alignment":"center"}}},{"id":"i35","component":{"Icon":{"name":{"literalString":"visibility"}}}},{"id":"l35","component":{"Text":{"text":{"literalString":"visibility"},"usageHint":"caption"}}},
        {"id":"g36","component":{"Column":{"children":{"explicitList":["i36","l36"]},"alignment":"center"}}},{"id":"i36","component":{"Icon":{"name":{"literalString":"visibilityOff"}}}},{"id":"l36","component":{"Text":{"text":{"literalString":"visibilityOff"},"usageHint":"caption"}}},
        {"id":"g37","component":{"Column":{"children":{"explicitList":["i37","l37"]},"alignment":"center"}}},{"id":"i37","component":{"Icon":{"name":{"literalString":"warning"}}}},{"id":"l37","component":{"Text":{"text":{"literalString":"warning"},"usageHint":"caption"}}},
        {"id":"g38","component":{"Column":{"children":{"explicitList":["i38","l38"]},"alignment":"center"}}},{"id":"i38","component":{"Icon":{"name":{"literalString":"shoppingCart"}}}},{"id":"l38","component":{"Text":{"text":{"literalString":"shoppingCart"},"usageHint":"caption"}}},
        {"id":"g39","component":{"Column":{"children":{"explicitList":["i39","l39"]},"alignment":"center"}}},{"id":"i39","component":{"Icon":{"name":{"literalString":"payment"}}}},{"id":"l39","component":{"Text":{"text":{"literalString":"payment"},"usageHint":"caption"}}},
        {"id":"g40","component":{"Column":{"children":{"explicitList":["i40","l40"]},"alignment":"center"}}},{"id":"i40","component":{"Icon":{"name":{"literalString":"locationOn"}}}},{"id":"l40","component":{"Text":{"text":{"literalString":"locationOn"},"usageHint":"caption"}}}
      ]}}),
      ~s({"beginRendering":{"surfaceId":"icon-all","root":"root"}})
    ]
  end

  defp image_fit do
    [
      ~S|{"surfaceUpdate":{"surfaceId":"image-fit","components":[{"id":"root","component":{"Row":{"children":{"explicitList":["c1","c2","c3"]},"distribution":"spaceEvenly"}}},{"id":"c1","component":{"Column":{"children":{"explicitList":["l1","img1"]},"alignment":"center"}}},{"id":"c2","component":{"Column":{"children":{"explicitList":["l2","img2"]},"alignment":"center"}}},{"id":"c3","component":{"Column":{"children":{"explicitList":["l3","img3"]},"alignment":"center"}}},{"id":"l1","component":{"Text":{"text":{"literalString":"contain"},"usageHint":"caption"}}},{"id":"l2","component":{"Text":{"text":{"literalString":"cover"},"usageHint":"caption"}}},{"id":"l3","component":{"Text":{"text":{"literalString":"fill"},"usageHint":"caption"}}},{"id":"img1","component":{"Image":{"url":{"literalString":"https://picsum.photos/400/200"},"fit":"contain","usageHint":"squareDemo"}}},{"id":"img2","component":{"Image":{"url":{"literalString":"https://picsum.photos/400/200"},"fit":"cover","usageHint":"squareDemo"}}},{"id":"img3","component":{"Image":{"url":{"literalString":"https://picsum.photos/400/200"},"fit":"fill","usageHint":"squareDemo"}}}]}}|,
      ~s({"beginRendering":{"surfaceId":"image-fit","root":"root"}})
    ]
  end

  defp image_usage_hints do
    [
      ~S|{"surfaceUpdate":{"surfaceId":"image-hints","components":[{"id":"root","component":{"Row":{"children":{"explicitList":["c1","c2","c3","c4"]},"distribution":"start","alignment":"end"}}},{"id":"c1","component":{"Column":{"children":{"explicitList":["l1","img1"]},"alignment":"center"}}},{"id":"c2","component":{"Column":{"children":{"explicitList":["l2","img2"]},"alignment":"center"}}},{"id":"c3","component":{"Column":{"children":{"explicitList":["l3","img3"]},"alignment":"center"}}},{"id":"c4","component":{"Column":{"children":{"explicitList":["l4","img4"]},"alignment":"center"}}},{"id":"l1","component":{"Text":{"text":{"literalString":"icon"},"usageHint":"caption"}}},{"id":"l2","component":{"Text":{"text":{"literalString":"avatar"},"usageHint":"caption"}}},{"id":"l3","component":{"Text":{"text":{"literalString":"smallFeature"},"usageHint":"caption"}}},{"id":"l4","component":{"Text":{"text":{"literalString":"mediumFeature"},"usageHint":"caption"}}},{"id":"img1","component":{"Image":{"url":{"literalString":"https://picsum.photos/100"},"usageHint":"icon"}}},{"id":"img2","component":{"Image":{"url":{"literalString":"https://picsum.photos/100"},"usageHint":"avatar"}}},{"id":"img3","component":{"Image":{"url":{"literalString":"https://picsum.photos/200"},"usageHint":"smallFeature"}}},{"id":"img4","component":{"Image":{"url":{"literalString":"https://picsum.photos/400"},"usageHint":"mediumFeature"}}}]}}|,
      ~s({"beginRendering":{"surfaceId":"image-hints","root":"root"}})
    ]
  end

  # ============================================
  # Media Components
  # ============================================

  defp audio_player do
    [
      ~S|{"surfaceUpdate":{"surfaceId":"audio","components":[{"id":"root","component":{"Column":{"children":{"explicitList":["title","player"]}}}},{"id":"title","component":{"Text":{"text":{"literalString":"Audio Player Example"},"usageHint":"h4"}}},{"id":"player","component":{"AudioPlayer":{"url":{"literalString":"https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3"},"description":{"literalString":"SoundHelix Demo Track"}}}}]}}|,
      ~s({"beginRendering":{"surfaceId":"audio","root":"root"}})
    ]
  end

  defp video_player do
    [
      ~S|{"surfaceUpdate":{"surfaceId":"video","components":[{"id":"root","component":{"Column":{"children":{"explicitList":["title","player"]}}}},{"id":"title","component":{"Text":{"text":{"literalString":"Video Player Example"},"usageHint":"h4"}}},{"id":"player","component":{"Video":{"url":{"literalString":"https://www.w3schools.com/html/mov_bbb.mp4"}}}}]}}|,
      ~s({"beginRendering":{"surfaceId":"video","root":"root"}})
    ]
  end

  # ============================================
  # Interactive Components
  # ============================================

  defp button_variants do
    [
      ~s({"surfaceUpdate":{"surfaceId":"button","components":[
        {"id":"root","component":{"Row":{"children":{"explicitList":["b1","b2"]},"distribution":"start"}}},
        {"id":"b1","component":{"Button":{"child":"t1","primary":true,"action":{"name":"primary_click"}}}},
        {"id":"t1","component":{"Text":{"text":{"literalString":"Primary Button"}}}},
        {"id":"b2","component":{"Button":{"child":"t2","primary":false,"action":{"name":"secondary_click"}}}},
        {"id":"t2","component":{"Text":{"text":{"literalString":"Secondary Button"}}}}
      ]}}),
      ~s({"beginRendering":{"surfaceId":"button","root":"root"}})
    ]
  end

  defp text_field_types do
    [
      ~s({"surfaceUpdate":{"surfaceId":"textfield","components":[
        {"id":"root","component":{"Column":{"children":{"explicitList":["f1","f2","f3","f4","f5"]}}}},
        {"id":"f1","component":{"TextField":{"label":{"literalString":"Short Text"},"text":{"path":"/short"},"textFieldType":"shortText"}}},
        {"id":"f2","component":{"TextField":{"label":{"literalString":"Long Text"},"text":{"path":"/long"},"textFieldType":"longText"}}},
        {"id":"f3","component":{"TextField":{"label":{"literalString":"Number"},"text":{"path":"/number"},"textFieldType":"number"}}},
        {"id":"f4","component":{"TextField":{"label":{"literalString":"Password"},"text":{"path":"/password"},"textFieldType":"obscured"}}},
        {"id":"f5","component":{"TextField":{"label":{"literalString":"Date"},"text":{"path":"/date"},"textFieldType":"date"}}}
      ]}}),
      ~s({"dataModelUpdate":{"surfaceId":"textfield","contents":[
        {"key":"short","valueString":"Hello"},
        {"key":"long","valueString":"This is a longer text that might span multiple lines."},
        {"key":"number","valueString":"42"},
        {"key":"password","valueString":"secret"},
        {"key":"date","valueString":"2024-06-15"}
      ]}}),
      ~s({"beginRendering":{"surfaceId":"textfield","root":"root"}})
    ]
  end

  defp text_field_validation do
    [
      ~s({"surfaceUpdate":{"surfaceId":"textfield-val","components":[
        {"id":"root","component":{"Column":{"children":{"explicitList":["label","f1"]}}}},
        {"id":"label","component":{"Text":{"text":{"literalString":"Email (must match pattern\)"},"usageHint":"caption"}}},
        {"id":"f1","component":{"TextField":{"label":{"literalString":"Email"},"text":{"path":"/email"},"textFieldType":"shortText","validationRegexp":"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\\\.[a-zA-Z]{2,}$"}}}
      ]}}),
      ~s({"dataModelUpdate":{"surfaceId":"textfield-val","contents":[{"key":"email","valueString":"invalid-email"}]}}),
      ~s({"beginRendering":{"surfaceId":"textfield-val","root":"root"}})
    ]
  end

  defp checkbox do
    [
      ~s|{"surfaceUpdate":{"surfaceId":"checkbox","components":[
        {"id":"root","component":{"Column":{"children":{"explicitList":["c1","c2","c3"]}}}},
        {"id":"c1","component":{"CheckBox":{"label":{"literalString":"Option A (checked)"},"value":{"path":"/optA"}}}},
        {"id":"c2","component":{"CheckBox":{"label":{"literalString":"Option B (unchecked)"},"value":{"path":"/optB"}}}},
        {"id":"c3","component":{"CheckBox":{"label":{"literalString":"Option C (checked)"},"value":{"path":"/optC"}}}}
      ]}}|,
      ~s|{"dataModelUpdate":{"surfaceId":"checkbox","contents":[
        {"key":"optA","valueBoolean":true},
        {"key":"optB","valueBoolean":false},
        {"key":"optC","valueBoolean":true}
      ]}}|,
      ~s({"beginRendering":{"surfaceId":"checkbox","root":"root"}})
    ]
  end

  defp slider do
    [
      ~s|{"surfaceUpdate":{"surfaceId":"slider","components":[
        {"id":"root","component":{"Column":{"children":{"explicitList":["l1","s1","l2","s2"]}}}},
        {"id":"l1","component":{"Text":{"text":{"literalString":"Volume (0-100)"},"usageHint":"caption"}}},
        {"id":"s1","component":{"Slider":{"value":{"path":"/volume"},"minValue":0,"maxValue":100}}},
        {"id":"l2","component":{"Text":{"text":{"literalString":"Temperature (15-30)"},"usageHint":"caption"}}},
        {"id":"s2","component":{"Slider":{"value":{"path":"/temp"},"minValue":15,"maxValue":30}}}
      ]}}|,
      ~s({"dataModelUpdate":{"surfaceId":"slider","contents":[
        {"key":"volume","valueNumber":75},
        {"key":"temp","valueNumber":22}
      ]}}),
      ~s({"beginRendering":{"surfaceId":"slider","root":"root"}})
    ]
  end

  defp datetime_input do
    [
      ~s({"surfaceUpdate":{"surfaceId":"datetime","components":[
        {"id":"root","component":{"Column":{"children":{"explicitList":["l1","dt1","l2","dt2","l3","dt3"]}}}},
        {"id":"l1","component":{"Text":{"text":{"literalString":"Date & Time"},"usageHint":"caption"}}},
        {"id":"dt1","component":{"DateTimeInput":{"value":{"path":"/datetime"},"enableDate":true,"enableTime":true}}},
        {"id":"l2","component":{"Text":{"text":{"literalString":"Date Only"},"usageHint":"caption"}}},
        {"id":"dt2","component":{"DateTimeInput":{"value":{"path":"/date"},"enableDate":true,"enableTime":false}}},
        {"id":"l3","component":{"Text":{"text":{"literalString":"Time Only"},"usageHint":"caption"}}},
        {"id":"dt3","component":{"DateTimeInput":{"value":{"path":"/time"},"enableDate":false,"enableTime":true}}}
      ]}}),
      ~s({"dataModelUpdate":{"surfaceId":"datetime","contents":[
        {"key":"datetime","valueString":"2024-06-15T14:30:00Z"},
        {"key":"date","valueString":"2024-06-15T00:00:00Z"},
        {"key":"time","valueString":"1970-01-01T14:30:00Z"}
      ]}}),
      ~s({"beginRendering":{"surfaceId":"datetime","root":"root"}})
    ]
  end

  defp multiple_choice_single do
    [
      ~s|{"surfaceUpdate":{"surfaceId":"choice-single","components":[
        {"id":"root","component":{"Column":{"children":{"explicitList":["label","choice"]}}}},
        {"id":"label","component":{"Text":{"text":{"literalString":"Select one option (radio buttons):"},"usageHint":"caption"}}},
        {"id":"choice","component":{"MultipleChoice":{"selections":{"path":"/selected"},"options":[
          {"label":{"literalString":"Option A"},"value":{"literalString":"a"}},
          {"label":{"literalString":"Option B"},"value":{"literalString":"b"}},
          {"label":{"literalString":"Option C"},"value":{"literalString":"c"}}
        ],"maxAllowedSelections":1}}}
      ]}}|,
      ~s({"dataModelUpdate":{"surfaceId":"choice-single","contents":[{"key":"selected","valueString":"b"}]}}),
      ~s({"beginRendering":{"surfaceId":"choice-single","root":"root"}})
    ]
  end

  defp multiple_choice_multi do
    [
      ~s|{"surfaceUpdate":{"surfaceId":"choice-multi","components":[
        {"id":"root","component":{"Column":{"children":{"explicitList":["label","choice","hint"]}}}},
        {"id":"label","component":{"Text":{"text":{"literalString":"Select up to 2 options (checkboxes):"},"usageHint":"caption"}}},
        {"id":"choice","component":{"MultipleChoice":{"selections":{"path":"/selected"},"options":[
          {"label":{"literalString":"Red"},"value":{"literalString":"red"}},
          {"label":{"literalString":"Green"},"value":{"literalString":"green"}},
          {"label":{"literalString":"Blue"},"value":{"literalString":"blue"}},
          {"label":{"literalString":"Yellow"},"value":{"literalString":"yellow"}}
        ],"maxAllowedSelections":2}}},
        {"id":"hint","component":{"Text":{"text":{"literalString":"(Options disable when max reached)"},"usageHint":"caption"}}}
      ]}}|,
      ~s({"beginRendering":{"surfaceId":"choice-multi","root":"root"}})
    ]
  end

  # ============================================
  # Container Components
  # ============================================

  defp tabs do
    [
      ~s({"surfaceUpdate":{"surfaceId":"tabs","components":[
        {"id":"root","component":{"Tabs":{"tabItems":[
          {"title":{"literalString":"Profile"},"child":"tab1"},
          {"title":{"literalString":"Settings"},"child":"tab2"},
          {"title":{"literalString":"Notifications"},"child":"tab3"}
        ]}}},
        {"id":"tab1","component":{"Column":{"children":{"explicitList":["t1","d1"]}}}},
        {"id":"t1","component":{"Text":{"text":{"literalString":"Profile Tab"},"usageHint":"h4"}}},
        {"id":"d1","component":{"Text":{"text":{"literalString":"This is the profile content. Edit your personal information here."}}}},
        {"id":"tab2","component":{"Column":{"children":{"explicitList":["t2","d2"]}}}},
        {"id":"t2","component":{"Text":{"text":{"literalString":"Settings Tab"},"usageHint":"h4"}}},
        {"id":"d2","component":{"Text":{"text":{"literalString":"Configure your application settings and preferences."}}}},
        {"id":"tab3","component":{"Column":{"children":{"explicitList":["t3","d3"]}}}},
        {"id":"t3","component":{"Text":{"text":{"literalString":"Notifications Tab"},"usageHint":"h4"}}},
        {"id":"d3","component":{"Text":{"text":{"literalString":"Manage your notification preferences and alerts."}}}}
      ]}}),
      ~s({"beginRendering":{"surfaceId":"tabs","root":"root"}})
    ]
  end

  defp modal do
    [
      ~s({"surfaceUpdate":{"surfaceId":"modal","components":[
        {"id":"root","component":{"Modal":{"entryPointChild":"trigger","contentChild":"dialog"}}},
        {"id":"trigger","component":{"Button":{"child":"trigger-text","primary":true}}},
        {"id":"trigger-text","component":{"Text":{"text":{"literalString":"Open Modal"}}}},
        {"id":"dialog","component":{"Column":{"children":{"explicitList":["title","body","actions"]}}}},
        {"id":"title","component":{"Text":{"text":{"literalString":"Modal Dialog"},"usageHint":"h3"}}},
        {"id":"body","component":{"Text":{"text":{"literalString":"This is the modal content. You can put any components here. Click outside or the X button to close."}}}},
        {"id":"actions","component":{"Row":{"children":{"explicitList":["cancel","confirm"]},"distribution":"end"}}},
        {"id":"cancel","component":{"Button":{"child":"cancel-text"}}},
        {"id":"cancel-text","component":{"Text":{"text":{"literalString":"Cancel"}}}},
        {"id":"confirm","component":{"Button":{"child":"confirm-text","primary":true}}},
        {"id":"confirm-text","component":{"Text":{"text":{"literalString":"Confirm"}}}}
      ]}}),
      ~s({"beginRendering":{"surfaceId":"modal","root":"root"}})
    ]
  end

  # ============================================
  # Advanced Examples
  # ============================================

  defp data_binding_example do
    [
      ~s({"surfaceUpdate":{"surfaceId":"binding","components":[
        {"id":"root","component":{"Column":{"children":{"explicitList":["title","input","output"]}}}},
        {"id":"title","component":{"Text":{"text":{"literalString":"Two-Way Data Binding"},"usageHint":"h4"}}},
        {"id":"input","component":{"TextField":{"label":{"literalString":"Type something"},"text":{"path":"/message"}}}},
        {"id":"output","component":{"Row":{"children":{"explicitList":["label","value"]}}}},
        {"id":"label","component":{"Text":{"text":{"literalString":"You typed: "},"usageHint":"caption"}}},
        {"id":"value","component":{"Text":{"text":{"path":"/message"}}}}
      ]}}),
      ~s({"dataModelUpdate":{"surfaceId":"binding","contents":[{"key":"message","valueString":"Hello World!"}]}}),
      ~s({"beginRendering":{"surfaceId":"binding","root":"root"}})
    ]
  end

  defp template_list do
    [
      ~s({"surfaceUpdate":{"surfaceId":"template","components":[
        {"id":"root","component":{"Column":{"children":{"explicitList":["title","list"]}}}},
        {"id":"title","component":{"Text":{"text":{"literalString":"Template-Generated List"},"usageHint":"h4"}}},
        {"id":"list","component":{"Column":{"children":{"template":{"dataBinding":"/items","componentId":"item"}}}}},
        {"id":"item","component":{"Card":{"child":"item-content"}}},
        {"id":"item-content","component":{"Row":{"children":{"explicitList":["item-icon","item-text"]}}}},
        {"id":"item-icon","component":{"Icon":{"name":{"path":"/icon"}}}},
        {"id":"item-text","component":{"Text":{"text":{"path":"/name"}}}}
      ]}}),
      ~s({"dataModelUpdate":{"surfaceId":"template","contents":[
        {"key":"items","valueMap":[
          {"key":"0","valueMap":[{"key":"name","valueString":"Home"},{"key":"icon","valueString":"home"}]},
          {"key":"1","valueMap":[{"key":"name","valueString":"Settings"},{"key":"icon","valueString":"settings"}]},
          {"key":"2","valueMap":[{"key":"name","valueString":"Profile"},{"key":"icon","valueString":"person"}]},
          {"key":"3","valueMap":[{"key":"name","valueString":"Messages"},{"key":"icon","valueString":"mail"}]}
        ]}
      ]}}),
      ~s({"beginRendering":{"surfaceId":"template","root":"root"}})
    ]
  end

  defp weight_example do
    [
      ~s|{"surfaceUpdate":{"surfaceId":"weight","components":[
        {"id":"root","component":{"Column":{"children":{"explicitList":["title","row"]}}}},
        {"id":"title","component":{"Text":{"text":{"literalString":"Flex Weight (flex-grow)"},"usageHint":"h4"}}},
        {"id":"row","component":{"Row":{"children":{"explicitList":["c1","c2","c3"]}}}},
        {"id":"c1","weight":1,"component":{"Card":{"child":"t1"}}},
        {"id":"t1","component":{"Text":{"text":{"literalString":"Weight: 1"}}}},
        {"id":"c2","weight":2,"component":{"Card":{"child":"t2"}}},
        {"id":"t2","component":{"Text":{"text":{"literalString":"Weight: 2"}}}},
        {"id":"c3","weight":1,"component":{"Card":{"child":"t3"}}},
        {"id":"t3","component":{"Text":{"text":{"literalString":"Weight: 1"}}}}
      ]}}|,
      ~s({"beginRendering":{"surfaceId":"weight","root":"root"}})
    ]
  end

  defp nested_layout do
    [
      ~s({"surfaceUpdate":{"surfaceId":"nested","components":[
        {"id":"root","component":{"Column":{"children":{"explicitList":["header","content","footer"]}}}},
        {"id":"header","component":{"Card":{"child":"header-content"}}},
        {"id":"header-content","component":{"Row":{"children":{"explicitList":["logo","nav"]},"distribution":"spaceBetween","alignment":"center"}}},
        {"id":"logo","component":{"Row":{"children":{"explicitList":["logo-icon","logo-text"]}}}},
        {"id":"logo-icon","component":{"Icon":{"name":{"literalString":"home"}}}},
        {"id":"logo-text","component":{"Text":{"text":{"literalString":"My App"},"usageHint":"h4"}}},
        {"id":"nav","weight":1,"component":{"Row":{"children":{"explicitList":["nav1","nav2","nav3"]},"distribution":"end"}}},
        {"id":"nav1","component":{"Button":{"child":"nav1-t"}}},{"id":"nav1-t","component":{"Text":{"text":{"literalString":"Home"}}}},
        {"id":"nav2","component":{"Button":{"child":"nav2-t"}}},{"id":"nav2-t","component":{"Text":{"text":{"literalString":"About"}}}},
        {"id":"nav3","component":{"Button":{"child":"nav3-t","primary":true}}},{"id":"nav3-t","component":{"Text":{"text":{"literalString":"Contact"}}}},
        {"id":"content","component":{"Row":{"children":{"explicitList":["sidebar","main"]},"alignment":"stretch"}}},
        {"id":"sidebar","weight":1,"component":{"Card":{"child":"sidebar-content"}}},
        {"id":"sidebar-content","component":{"Column":{"children":{"explicitList":["sb-title","sb-items"]}}}},
        {"id":"sb-title","component":{"Text":{"text":{"literalString":"Navigation"},"usageHint":"h5"}}},
        {"id":"sb-items","component":{"Column":{"children":{"explicitList":["sb1","sb2","sb3"]}}}},
        {"id":"sb1","component":{"Text":{"text":{"literalString":"Dashboard"}}}},
        {"id":"sb2","component":{"Text":{"text":{"literalString":"Analytics"}}}},
        {"id":"sb3","component":{"Text":{"text":{"literalString":"Reports"}}}},
        {"id":"main","weight":3,"component":{"Card":{"child":"main-content"}}},
        {"id":"main-content","component":{"Column":{"children":{"explicitList":["main-title","main-text"]}}}},
        {"id":"main-title","component":{"Text":{"text":{"literalString":"Main Content"},"usageHint":"h3"}}},
        {"id":"main-text","component":{"Text":{"text":{"literalString":"This is a nested layout example showing header, sidebar, main content, and footer areas. The sidebar has weight 1 and main content has weight 3."}}}},
        {"id":"footer","component":{"Card":{"child":"footer-content"}}},
        {"id":"footer-content","component":{"Row":{"children":{"explicitList":["footer-text"]},"distribution":"center"}}},
        {"id":"footer-text","component":{"Text":{"text":{"literalString":"© 2024 My App. All rights reserved."},"usageHint":"caption"}}}
      ]}}),
      ~s({"beginRendering":{"surfaceId":"nested","root":"root"}})
    ]
  end
end
