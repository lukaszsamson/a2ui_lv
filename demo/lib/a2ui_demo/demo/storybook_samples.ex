defmodule A2UIDemo.Demo.StorybookSamples do
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
      {"Layout", "Column - Alignments", "column-align", column_alignments()},
      {"Layout", "Row - Basic", "row-basic", row_basic()},
      {"Layout", "Row - Alignments", "row-align", row_alignments()},
      {"Layout", "Row - Distributions", "row-dist", row_distributions()},
      {"Layout", "Card", "card-basic", card_basic()},
      {"Layout", "List - Vertical", "list-vert", list_vertical()},
      {"Layout", "List - Horizontal", "list-horiz", list_horizontal()},

      # Display Components
      {"Display", "Text - Headings", "text-headings", text_headings()},
      {"Display", "Text - Body & Caption", "text-body", text_body()},
      {"Display", "Divider - Basic", "divider", divider()},
      {"Display", "Divider - Variants", "divider-variants", divider_variants()},
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
      {"Advanced", "Nested Layout", "nested", nested_layout()},

      # v0.9 Features - Demonstrating protocol changes
      {"v0.9 Features", "Message Format", "v09-message", v09_message_format()},
      {"v0.9 Features", "Layout justify/align", "v09-layout", v09_layout_props()},
      {"v0.9 Features", "Text variant", "v09-text", v09_text_variant()},
      {"v0.9 Features", "TextField value/checks", "v09-textfield", v09_textfield()},
      {"v0.9 Features", "ChoicePicker", "v09-choice", v09_choice_picker()},
      {"v0.9 Features", "Slider min/max", "v09-slider", v09_slider()},
      {"v0.9 Features", "Tabs (tabs prop)", "v09-tabs", v09_tabs()},
      {"v0.9 Features", "Modal trigger/content", "v09-modal", v09_modal()},
      {"v0.9 Features", "Button context (map)", "v09-button", v09_button_context()},
      {"v0.9 Features", "String Format", "v09-stringformat", v09_string_format()},

      # Gallery Examples (from A2UI Composer)
      {"Gallery", "Flight Status", "gallery-flight", gallery_flight_status()},
      {"Gallery", "Notification", "gallery-notification", gallery_notification()},
      {"Gallery", "Movie Card", "gallery-movie", gallery_movie_card()},
      {"Gallery", "Weather", "gallery-weather", gallery_weather()},
      {"Gallery", "Task Card", "gallery-task", gallery_task_card()},
      {"Gallery", "Stats Card", "gallery-stats", gallery_stats_card()},
      {"Gallery", "Account Balance", "gallery-account", gallery_account_balance()},
      {"Gallery", "Step Counter", "gallery-steps", gallery_step_counter()},
      {"Gallery", "Countdown Timer", "gallery-countdown", gallery_countdown_timer()},
      {"Gallery", "Login Form", "gallery-login", gallery_login_form()},
      {"Gallery", "Contact Card", "gallery-contact", gallery_contact_card()},
      {"Gallery", "User Profile", "gallery-profile", gallery_user_profile()},
      {"Gallery", "Product Card", "gallery-product", gallery_product_card()},
      {"Gallery", "Podcast Episode", "gallery-podcast", gallery_podcast_episode()},
      {"Gallery", "Purchase Complete", "gallery-purchase", gallery_purchase_complete()},
      {"Gallery", "Shipping Status", "gallery-shipping", gallery_shipping_status()},
      {"Gallery", "Calendar Day", "gallery-calendar", gallery_calendar_day()},
      {"Gallery", "Chat Thread", "gallery-chat", gallery_chat_thread()},
      {"Gallery", "Credit Card", "gallery-creditcard", gallery_credit_card()},
      {"Gallery", "Coffee Order", "gallery-coffee", gallery_coffee_order()},
      {"Gallery", "Restaurant Card", "gallery-restaurant", gallery_restaurant_card()},
      {"Gallery", "Email Compose", "gallery-email", gallery_email_compose()},
      {"Gallery", "Sports Player", "gallery-player", gallery_sports_player()},
      {"Gallery", "Recipe Card", "gallery-recipe", gallery_recipe_card()},
      {"Gallery", "Music Player", "gallery-music", gallery_music_player()},
      {"Gallery", "Workout Summary", "gallery-workout", gallery_workout_summary()},
      {"Gallery", "Event Detail", "gallery-event", gallery_event_detail()},
      {"Gallery", "Track List", "gallery-tracklist", gallery_track_list()}
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
      ~S|{"surfaceUpdate":{"surfaceId":"column-dist","components":[{"id":"root","component":{"Row":{"children":{"explicitList":["c1","c2","c3","c4"]},"distribution":"spaceEvenly"}}},{"id":"c1","component":{"Column":{"children":{"explicitList":["l1","box1"]},"alignment":"center"}}},{"id":"c2","component":{"Column":{"children":{"explicitList":["l2","box2"]},"alignment":"center"}}},{"id":"c3","component":{"Column":{"children":{"explicitList":["l3","box3"]},"alignment":"center"}}},{"id":"c4","component":{"Column":{"children":{"explicitList":["l4","box4"]},"alignment":"center"}}},{"id":"l1","component":{"Text":{"text":{"literalString":"start"},"usageHint":"caption"}}},{"id":"l2","component":{"Text":{"text":{"literalString":"center"},"usageHint":"caption"}}},{"id":"l3","component":{"Text":{"text":{"literalString":"end"},"usageHint":"caption"}}},{"id":"l4","component":{"Text":{"text":{"literalString":"spaceBetween"},"usageHint":"caption"}}},{"id":"box1","component":{"Card":{"child":"inner1"}}},{"id":"box2","component":{"Card":{"child":"inner2"}}},{"id":"box3","component":{"Card":{"child":"inner3"}}},{"id":"box4","component":{"Card":{"child":"inner4"}}},{"id":"inner1","component":{"Column":{"children":{"explicitList":["i1a","i1b"]},"distribution":"start"}}},{"id":"inner2","component":{"Column":{"children":{"explicitList":["i2a","i2b"]},"distribution":"center"}}},{"id":"inner3","component":{"Column":{"children":{"explicitList":["i3a","i3b"]},"distribution":"end"}}},{"id":"inner4","component":{"Column":{"children":{"explicitList":["i4a","i4b"]},"distribution":"spaceBetween"}}},{"id":"i1a","component":{"Text":{"text":{"literalString":"Top"}}}},{"id":"i1b","component":{"Text":{"text":{"literalString":"Item"}}}},{"id":"i2a","component":{"Text":{"text":{"literalString":"Top"}}}},{"id":"i2b","component":{"Text":{"text":{"literalString":"Item"}}}},{"id":"i3a","component":{"Text":{"text":{"literalString":"Top"}}}},{"id":"i3b","component":{"Text":{"text":{"literalString":"Item"}}}},{"id":"i4a","component":{"Text":{"text":{"literalString":"Top"}}}},{"id":"i4b","component":{"Text":{"text":{"literalString":"Item"}}}}]}}|,
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

  defp row_distributions do
    [
      ~S|{"surfaceUpdate":{"surfaceId":"row-dist","components":[{"id":"root","component":{"Column":{"children":{"explicitList":["label1","r1","label2","r2","label3","r3","label4","r4","label5","r5","label6","r6"]}}}},{"id":"label1","component":{"Text":{"text":{"literalString":"distribution: start (default)"},"usageHint":"caption"}}},{"id":"r1","component":{"Row":{"children":{"explicitList":["b1a","b1b","b1c"]},"distribution":"start"}}},{"id":"label2","component":{"Text":{"text":{"literalString":"distribution: center"},"usageHint":"caption"}}},{"id":"r2","component":{"Row":{"children":{"explicitList":["b2a","b2b","b2c"]},"distribution":"center"}}},{"id":"label3","component":{"Text":{"text":{"literalString":"distribution: end"},"usageHint":"caption"}}},{"id":"r3","component":{"Row":{"children":{"explicitList":["b3a","b3b","b3c"]},"distribution":"end"}}},{"id":"label4","component":{"Text":{"text":{"literalString":"distribution: spaceBetween"},"usageHint":"caption"}}},{"id":"r4","component":{"Row":{"children":{"explicitList":["b4a","b4b","b4c"]},"distribution":"spaceBetween"}}},{"id":"label5","component":{"Text":{"text":{"literalString":"distribution: spaceAround"},"usageHint":"caption"}}},{"id":"r5","component":{"Row":{"children":{"explicitList":["b5a","b5b","b5c"]},"distribution":"spaceAround"}}},{"id":"label6","component":{"Text":{"text":{"literalString":"distribution: spaceEvenly"},"usageHint":"caption"}}},{"id":"r6","component":{"Row":{"children":{"explicitList":["b6a","b6b","b6c"]},"distribution":"spaceEvenly"}}},{"id":"b1a","component":{"Button":{"child":"t1a"}}},{"id":"t1a","component":{"Text":{"text":{"literalString":"A"}}}},{"id":"b1b","component":{"Button":{"child":"t1b"}}},{"id":"t1b","component":{"Text":{"text":{"literalString":"B"}}}},{"id":"b1c","component":{"Button":{"child":"t1c"}}},{"id":"t1c","component":{"Text":{"text":{"literalString":"C"}}}},{"id":"b2a","component":{"Button":{"child":"t2a"}}},{"id":"t2a","component":{"Text":{"text":{"literalString":"A"}}}},{"id":"b2b","component":{"Button":{"child":"t2b"}}},{"id":"t2b","component":{"Text":{"text":{"literalString":"B"}}}},{"id":"b2c","component":{"Button":{"child":"t2c"}}},{"id":"t2c","component":{"Text":{"text":{"literalString":"C"}}}},{"id":"b3a","component":{"Button":{"child":"t3a"}}},{"id":"t3a","component":{"Text":{"text":{"literalString":"A"}}}},{"id":"b3b","component":{"Button":{"child":"t3b"}}},{"id":"t3b","component":{"Text":{"text":{"literalString":"B"}}}},{"id":"b3c","component":{"Button":{"child":"t3c"}}},{"id":"t3c","component":{"Text":{"text":{"literalString":"C"}}}},{"id":"b4a","component":{"Button":{"child":"t4a"}}},{"id":"t4a","component":{"Text":{"text":{"literalString":"A"}}}},{"id":"b4b","component":{"Button":{"child":"t4b"}}},{"id":"t4b","component":{"Text":{"text":{"literalString":"B"}}}},{"id":"b4c","component":{"Button":{"child":"t4c"}}},{"id":"t4c","component":{"Text":{"text":{"literalString":"C"}}}},{"id":"b5a","component":{"Button":{"child":"t5a"}}},{"id":"t5a","component":{"Text":{"text":{"literalString":"A"}}}},{"id":"b5b","component":{"Button":{"child":"t5b"}}},{"id":"t5b","component":{"Text":{"text":{"literalString":"B"}}}},{"id":"b5c","component":{"Button":{"child":"t5c"}}},{"id":"t5c","component":{"Text":{"text":{"literalString":"C"}}}},{"id":"b6a","component":{"Button":{"child":"t6a"}}},{"id":"t6a","component":{"Text":{"text":{"literalString":"A"}}}},{"id":"b6b","component":{"Button":{"child":"t6b"}}},{"id":"t6b","component":{"Text":{"text":{"literalString":"B"}}}},{"id":"b6c","component":{"Button":{"child":"t6c"}}},{"id":"t6c","component":{"Text":{"text":{"literalString":"C"}}}}]}}|,
      ~s({"beginRendering":{"surfaceId":"row-dist","root":"root"}})
    ]
  end

  defp column_alignments do
    [
      ~S|{"surfaceUpdate":{"surfaceId":"column-align","components":[{"id":"root","component":{"Row":{"children":{"explicitList":["c1","c2","c3","c4"]},"distribution":"spaceEvenly"}}},{"id":"c1","component":{"Column":{"children":{"explicitList":["l1","card1"]},"alignment":"start"}}},{"id":"c2","component":{"Column":{"children":{"explicitList":["l2","card2"]},"alignment":"center"}}},{"id":"c3","component":{"Column":{"children":{"explicitList":["l3","card3"]},"alignment":"end"}}},{"id":"c4","component":{"Column":{"children":{"explicitList":["l4","card4"]},"alignment":"stretch"}}},{"id":"l1","component":{"Text":{"text":{"literalString":"start"},"usageHint":"caption"}}},{"id":"l2","component":{"Text":{"text":{"literalString":"center"},"usageHint":"caption"}}},{"id":"l3","component":{"Text":{"text":{"literalString":"end"},"usageHint":"caption"}}},{"id":"l4","component":{"Text":{"text":{"literalString":"stretch"},"usageHint":"caption"}}},{"id":"card1","component":{"Card":{"child":"ct1"}}},{"id":"ct1","component":{"Text":{"text":{"literalString":"Card"}}}},{"id":"card2","component":{"Card":{"child":"ct2"}}},{"id":"ct2","component":{"Text":{"text":{"literalString":"Card"}}}},{"id":"card3","component":{"Card":{"child":"ct3"}}},{"id":"ct3","component":{"Text":{"text":{"literalString":"Card"}}}},{"id":"card4","component":{"Card":{"child":"ct4"}}},{"id":"ct4","component":{"Text":{"text":{"literalString":"Card"}}}}]}}|,
      ~s({"beginRendering":{"surfaceId":"column-align","root":"root"}})
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

  defp divider_variants do
    [
      ~S|{"surfaceUpdate":{"surfaceId":"divider-variants","components":[{"id":"root","component":{"Column":{"children":{"explicitList":["t1","d1","t2","d2","t3","d3","t4","d4","t5","color-row"]}}}},{"id":"t1","component":{"Text":{"text":{"literalString":"Default thickness (2px)"},"usageHint":"caption"}}},{"id":"d1","component":{"Divider":{}}},{"id":"t2","component":{"Text":{"text":{"literalString":"Thickness: 1px"},"usageHint":"caption"}}},{"id":"d2","component":{"Divider":{"thickness":1}}},{"id":"t3","component":{"Text":{"text":{"literalString":"Thickness: 4px"},"usageHint":"caption"}}},{"id":"d3","component":{"Divider":{"thickness":4}}},{"id":"t4","component":{"Text":{"text":{"literalString":"Thickness: 8px"},"usageHint":"caption"}}},{"id":"d4","component":{"Divider":{"thickness":8}}},{"id":"t5","component":{"Text":{"text":{"literalString":"With colors:"},"usageHint":"caption"}}},{"id":"color-row","component":{"Column":{"children":{"explicitList":["dc1","dc2","dc3","dc4"]}}}},{"id":"dc1","component":{"Divider":{"thickness":4,"color":"#ef4444"}}},{"id":"dc2","component":{"Divider":{"thickness":4,"color":"#22c55e"}}},{"id":"dc3","component":{"Divider":{"thickness":4,"color":"#3b82f6"}}},{"id":"dc4","component":{"Divider":{"thickness":4,"color":"#a855f7"}}}]}}|,
      ~s({"beginRendering":{"surfaceId":"divider-variants","root":"root"}})
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
    # Show all 40 standard icons with labels - 4 icons per row (10 rows) to accommodate long names
    [
      ~s({"surfaceUpdate":{"surfaceId":"icon-all","components":[
        {"id":"root","component":{"Column":{"children":{"explicitList":["row1","row2","row3","row4","row5","row6","row7","row8","row9","row10"]}}}},
        {"id":"row1","component":{"Row":{"children":{"explicitList":["g1","g2","g3","g4"]},"distribution":"spaceEvenly"}}},
        {"id":"row2","component":{"Row":{"children":{"explicitList":["g5","g6","g7","g8"]},"distribution":"spaceEvenly"}}},
        {"id":"row3","component":{"Row":{"children":{"explicitList":["g9","g10","g11","g12"]},"distribution":"spaceEvenly"}}},
        {"id":"row4","component":{"Row":{"children":{"explicitList":["g13","g14","g15","g16"]},"distribution":"spaceEvenly"}}},
        {"id":"row5","component":{"Row":{"children":{"explicitList":["g17","g18","g19","g20"]},"distribution":"spaceEvenly"}}},
        {"id":"row6","component":{"Row":{"children":{"explicitList":["g21","g22","g23","g24"]},"distribution":"spaceEvenly"}}},
        {"id":"row7","component":{"Row":{"children":{"explicitList":["g25","g26","g27","g28"]},"distribution":"spaceEvenly"}}},
        {"id":"row8","component":{"Row":{"children":{"explicitList":["g29","g30","g31","g32"]},"distribution":"spaceEvenly"}}},
        {"id":"row9","component":{"Row":{"children":{"explicitList":["g33","g34","g35","g36"]},"distribution":"spaceEvenly"}}},
        {"id":"row10","component":{"Row":{"children":{"explicitList":["g37","g38","g39","g40"]},"distribution":"spaceEvenly"}}},
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
    # Using 600x150 panoramic image in 128x96 smallFeature container to clearly show fit differences
    [
      ~S|{"surfaceUpdate":{"surfaceId":"image-fit","components":[{"id":"root","component":{"Row":{"children":{"explicitList":["c1","c2","c3"]},"distribution":"spaceEvenly"}}},{"id":"c1","component":{"Column":{"children":{"explicitList":["l1","img1"]},"alignment":"center"}}},{"id":"c2","component":{"Column":{"children":{"explicitList":["l2","img2"]},"alignment":"center"}}},{"id":"c3","component":{"Column":{"children":{"explicitList":["l3","img3"]},"alignment":"center"}}},{"id":"l1","component":{"Text":{"text":{"literalString":"contain"},"usageHint":"caption"}}},{"id":"l2","component":{"Text":{"text":{"literalString":"cover"},"usageHint":"caption"}}},{"id":"l3","component":{"Text":{"text":{"literalString":"fill"},"usageHint":"caption"}}},{"id":"img1","component":{"Image":{"url":{"literalString":"https://picsum.photos/600/150"},"fit":"contain","usageHint":"smallFeature"}}},{"id":"img2","component":{"Image":{"url":{"literalString":"https://picsum.photos/600/150"},"fit":"cover","usageHint":"smallFeature"}}},{"id":"img3","component":{"Image":{"url":{"literalString":"https://picsum.photos/600/150"},"fit":"fill","usageHint":"smallFeature"}}}]}}|,
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
        {"key":"date","valueString":"2024-06-15"},
        {"key":"time","valueString":"14:30:00"}
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
          {"label":{"literalString":"Option A"},"value":"a"},
          {"label":{"literalString":"Option B"},"value":"b"},
          {"label":{"literalString":"Option C"},"value":"c"}
        ],"maxAllowedSelections":1}}}
      ]}}|,
      ~s({"dataModelUpdate":{"surfaceId":"choice-single","contents":[{"key":"selected","valueMap":[{"key":"0","valueString":"b"}]}]}}),
      ~s({"beginRendering":{"surfaceId":"choice-single","root":"root"}})
    ]
  end

  defp multiple_choice_multi do
    [
      ~s|{"surfaceUpdate":{"surfaceId":"choice-multi","components":[
        {"id":"root","component":{"Column":{"children":{"explicitList":["label","choice","hint"]}}}},
        {"id":"label","component":{"Text":{"text":{"literalString":"Select up to 2 options (checkboxes):"},"usageHint":"caption"}}},
        {"id":"choice","component":{"MultipleChoice":{"selections":{"path":"/selected"},"options":[
          {"label":{"literalString":"Red"},"value":"red"},
          {"label":{"literalString":"Green"},"value":"green"},
          {"label":{"literalString":"Blue"},"value":"blue"},
          {"label":{"literalString":"Yellow"},"value":"yellow"}
        ],"maxAllowedSelections":2}}},
        {"id":"hint","component":{"Text":{"text":{"literalString":"(Options disable when max reached)"},"usageHint":"caption"}}}
      ]}}|,
      ~s({"dataModelUpdate":{"surfaceId":"choice-multi","contents":[{"key":"selected","valueMap":[{"key":"0","valueString":"red"},{"key":"1","valueString":"green"}]}]}}),
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
    # Using v0.9 format: updateDataModel with path and value (raw JSON)
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
      ~s({"updateDataModel":{"surfaceId":"template","path":"/items","value":{"0":{"name":"Home","icon":"home"},"1":{"name":"Settings","icon":"settings"},"2":{"name":"Profile","icon":"person"},"3":{"name":"Messages","icon":"mail"}}}}),
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

  # ============================================
  # v0.9 Features - Protocol Changes
  # ============================================

  defp v09_message_format do
    # v0.9 native wire format:
    # - createSurface (requires catalogId)
    # - updateComponents (flat component structure)
    # - children as plain arrays
    [
      ~S|{"createSurface":{"surfaceId":"v09-message","catalogId":"https://a2ui.dev/specification/v0_9/standard_catalog.json"}}|,
      ~S|{"updateComponents":{"surfaceId":"v09-message","components":[
        {"id":"root","component":"Column","children":["title","desc","code"]},
        {"id":"title","component":"Text","text":"v0.9 Native Wire Format","variant":"h3"},
        {"id":"desc","component":"Text","text":"This sample uses native v0.9 wire format: createSurface, updateComponents, flat component structure."},
        {"id":"code","component":"Card","child":"code-content"},
        {"id":"code-content","component":"Column","children":["c1","c2","c3","c4","c5"]},
        {"id":"c1","component":"Text","text":"• createSurface (was beginRendering)","variant":"caption"},
        {"id":"c2","component":"Text","text":"• updateComponents (was surfaceUpdate)","variant":"caption"},
        {"id":"c3","component":"Text","text":"• updateDataModel (was dataModelUpdate)","variant":"caption"},
        {"id":"c4","component":"Text","text":"• Flat component: {\"component\": \"Text\", \"text\": \"...\"}","variant":"caption"},
        {"id":"c5","component":"Text","text":"• Children as array: [\"a\", \"b\", \"c\"]","variant":"caption"}
      ]}}|
    ]
  end

  defp v09_layout_props do
    # v0.9 native wire format with justify/align props
    [
      ~S|{"createSurface":{"surfaceId":"v09-layout","catalogId":"https://a2ui.dev/specification/v0_9/standard_catalog.json"}}|,
      ~S|{"updateComponents":{"surfaceId":"v09-layout","components":[
        {"id":"root","component":"Column","children":["title","row1-label","row1","row2-label","row2","row3-label","row3"]},
        {"id":"title","component":"Text","text":"v0.9 Layout: justify & align","variant":"h4"},
        {"id":"row1-label","component":"Text","text":"justify: spaceBetween, align: center","variant":"caption"},
        {"id":"row1","component":"Row","children":["r1a","r1b","r1c"],"justify":"spaceBetween","align":"center"},
        {"id":"r1a","component":"Button","child":"r1a-t"},
        {"id":"r1a-t","component":"Text","text":"A"},
        {"id":"r1b","component":"Button","child":"r1b-t"},
        {"id":"r1b-t","component":"Text","text":"B"},
        {"id":"r1c","component":"Button","child":"r1c-t"},
        {"id":"r1c-t","component":"Text","text":"C"},
        {"id":"row2-label","component":"Text","text":"justify: spaceEvenly, align: stretch","variant":"caption"},
        {"id":"row2","component":"Row","children":["r2a","r2b"],"justify":"spaceEvenly","align":"stretch"},
        {"id":"r2a","component":"Card","child":"r2a-t"},
        {"id":"r2a-t","component":"Text","text":"Card 1"},
        {"id":"r2b","component":"Card","child":"r2b-t"},
        {"id":"r2b-t","component":"Text","text":"Card 2"},
        {"id":"row3-label","component":"Text","text":"justify: end, align: end","variant":"caption"},
        {"id":"row3","component":"Row","children":["r3a","r3b"],"justify":"end","align":"end"},
        {"id":"r3a","component":"Icon","name":"star"},
        {"id":"r3b","component":"Text","text":"Aligned to end"}
      ]}}|
    ]
  end

  defp v09_text_variant do
    # v0.9 native wire format with variant prop
    [
      ~S|{"createSurface":{"surfaceId":"v09-text","catalogId":"https://a2ui.dev/specification/v0_9/standard_catalog.json"}}|,
      ~S|{"updateComponents":{"surfaceId":"v09-text","components":[
        {"id":"root","component":"Column","children":["title","h1","h2","h3","h4","h5","body","caption"]},
        {"id":"title","component":"Text","text":"v0.9 Text: variant prop","variant":"h4"},
        {"id":"h1","component":"Text","text":"variant: h1","variant":"h1"},
        {"id":"h2","component":"Text","text":"variant: h2","variant":"h2"},
        {"id":"h3","component":"Text","text":"variant: h3","variant":"h3"},
        {"id":"h4","component":"Text","text":"variant: h4","variant":"h4"},
        {"id":"h5","component":"Text","text":"variant: h5","variant":"h5"},
        {"id":"body","component":"Text","text":"variant: body (default)","variant":"body"},
        {"id":"caption","component":"Text","text":"variant: caption","variant":"caption"}
      ]}}|
    ]
  end

  defp v09_textfield do
    # v0.9 native wire format with value, variant, checks
    [
      ~S|{"createSurface":{"surfaceId":"v09-textfield","catalogId":"https://a2ui.dev/specification/v0_9/standard_catalog.json"}}|,
      ~S|{"updateComponents":{"surfaceId":"v09-textfield","components":[
        {"id":"root","component":"Column","children":["title","tf1","tf2","tf3","tf4"]},
        {"id":"title","component":"Text","text":"v0.9 TextField: value, variant, checks","variant":"h4"},
        {"id":"tf1","component":"TextField","label":"Email (variant: email)","value":{"path":"/email"},"variant":"email","checks":[{"call":"required"},{"call":"email"}]},
        {"id":"tf2","component":"TextField","label":"Password (variant: password)","value":{"path":"/password"},"variant":"password","checks":[{"call":"required"},{"call":"length","args":{"min":8}}]},
        {"id":"tf3","component":"TextField","label":"Phone (with regex check)","value":{"path":"/phone"},"checks":[{"call":"regex","args":{"pattern":"^[0-9-]+$","message":"Numbers and dashes only"}}]},
        {"id":"tf4","component":"TextField","label":"Username (required + length)","value":{"path":"/username"},"checks":[{"call":"required"},{"call":"length","args":{"min":3,"max":20}}]}
      ]}}|,
      ~S|{"updateDataModel":{"surfaceId":"v09-textfield","path":"/","value":{"email":"","password":"","phone":"","username":""}}}|
    ]
  end

  defp v09_choice_picker do
    # v0.9 native wire format: ChoicePicker component
    # - value (DynamicStringList) - array of selected values
    # - variant ("mutuallyExclusive"/"multipleSelection")
    # - options: label (DynamicString) + value (string)
    [
      ~S|{"createSurface":{"surfaceId":"v09-choice","catalogId":"https://a2ui.dev/specification/v0_9/standard_catalog.json"}}|,
      ~S|{"updateComponents":{"surfaceId":"v09-choice","components":[
        {"id":"root","component":"Column","children":["title","cp1-label","cp1","cp2-label","cp2"]},
        {"id":"title","component":"Text","text":"v0.9 ChoicePicker","variant":"h4"},
        {"id":"cp1-label","component":"Text","text":"variant: mutuallyExclusive (radio buttons)","variant":"caption"},
        {"id":"cp1","component":"ChoicePicker","options":[{"label":"Option A","value":"opt1"},{"label":"Option B","value":"opt2"},{"label":"Option C","value":"opt3"}],"value":{"path":"/single"},"variant":"mutuallyExclusive"},
        {"id":"cp2-label","component":"Text","text":"variant: multipleSelection (checkboxes)","variant":"caption"},
        {"id":"cp2","component":"ChoicePicker","options":[{"label":"Red","value":"red"},{"label":"Green","value":"green"},{"label":"Blue","value":"blue"}],"value":{"path":"/multi"},"variant":"multipleSelection"}
      ]}}|,
      ~S|{"updateDataModel":{"surfaceId":"v09-choice","path":"/","value":{"single":["opt1"],"multi":["red","blue"]}}}|
    ]
  end

  defp v09_slider do
    # v0.9 native wire format with min/max props
    [
      ~S|{"createSurface":{"surfaceId":"v09-slider","catalogId":"https://a2ui.dev/specification/v0_9/standard_catalog.json"}}|,
      ~S|{"updateComponents":{"surfaceId":"v09-slider","components":[
        {"id":"root","component":"Column","children":["title","s1-label","s1","s2-label","s2"]},
        {"id":"title","component":"Text","text":"v0.9 Slider: min/max","variant":"h4"},
        {"id":"s1-label","component":"Text","text":"Volume (min: 0, max: 100)","variant":"caption"},
        {"id":"s1","component":"Slider","value":{"path":"/volume"},"min":0,"max":100},
        {"id":"s2-label","component":"Text","text":"Temperature (min: -20, max: 50)","variant":"caption"},
        {"id":"s2","component":"Slider","value":{"path":"/temp"},"min":-20,"max":50}
      ]}}|,
      ~S|{"updateDataModel":{"surfaceId":"v09-slider","path":"/","value":{"volume":75,"temp":22}}}|
    ]
  end

  defp v09_tabs do
    # v0.9 native wire format: tabs prop with title (DynamicString) and child
    [
      ~S|{"createSurface":{"surfaceId":"v09-tabs","catalogId":"https://a2ui.dev/specification/v0_9/standard_catalog.json"}}|,
      ~S|{"updateComponents":{"surfaceId":"v09-tabs","components":[
        {"id":"root","component":"Column","children":["heading","mytabs"]},
        {"id":"heading","component":"Text","text":"v0.9 Tabs: tabs prop","variant":"h4"},
        {"id":"mytabs","component":"Tabs","tabs":[{"title":"Overview","child":"tab1"},{"title":"Details","child":"tab2"},{"title":"Settings","child":"tab3"}]},
        {"id":"tab1","component":"Column","children":["tab1-title","tab1-text"]},
        {"id":"tab1-title","component":"Text","text":"Overview Tab","variant":"h4"},
        {"id":"tab1-text","component":"Text","text":"This is the overview content."},
        {"id":"tab2","component":"Column","children":["tab2-title","tab2-text"]},
        {"id":"tab2-title","component":"Text","text":"Details Tab","variant":"h4"},
        {"id":"tab2-text","component":"Text","text":"Here are the detailed information."},
        {"id":"tab3","component":"Column","children":["tab3-title","tab3-text"]},
        {"id":"tab3-title","component":"Text","text":"Settings Tab","variant":"h4"},
        {"id":"tab3-text","component":"Text","text":"Configure your preferences here."}
      ]}}|
    ]
  end

  defp v09_modal do
    # v0.9 native wire format: trigger and content props
    [
      ~S|{"createSurface":{"surfaceId":"v09-modal","catalogId":"https://a2ui.dev/specification/v0_9/standard_catalog.json"}}|,
      ~S|{"updateComponents":{"surfaceId":"v09-modal","components":[
        {"id":"root","component":"Modal","trigger":"trigger-btn","content":"dialog"},
        {"id":"trigger-btn","component":"Button","child":"trigger-text","primary":true},
        {"id":"trigger-text","component":"Text","text":"Open Modal (v0.9 trigger/content)"},
        {"id":"dialog","component":"Column","children":["dlg-title","dlg-body","dlg-actions"]},
        {"id":"dlg-title","component":"Text","text":"v0.9 Modal Props","variant":"h3"},
        {"id":"dlg-body","component":"Text","text":"This modal uses v0.9 props: trigger and content (was entryPointChild and contentChild)."},
        {"id":"dlg-actions","component":"Row","children":["cancel-btn","confirm-btn"],"justify":"end"},
        {"id":"cancel-btn","component":"Button","child":"cancel-text"},
        {"id":"cancel-text","component":"Text","text":"Cancel"},
        {"id":"confirm-btn","component":"Button","child":"confirm-text","primary":true},
        {"id":"confirm-text","component":"Text","text":"Confirm"}
      ]}}|
    ]
  end

  defp v09_button_context do
    # v0.9 native wire format: context as a standard map
    [
      ~S|{"createSurface":{"surfaceId":"v09-button","catalogId":"https://a2ui.dev/specification/v0_9/standard_catalog.json"}}|,
      ~S|{"updateComponents":{"surfaceId":"v09-button","components":[
        {"id":"root","component":"Column","children":["title","desc","btns"]},
        {"id":"title","component":"Text","text":"v0.9 Button: context as map","variant":"h4"},
        {"id":"desc","component":"Text","text":"Button context is now a standard JSON object instead of array of key-value pairs."},
        {"id":"btns","component":"Row","children":["btn1","btn2","btn3"],"justify":"start"},
        {"id":"btn1","component":"Button","child":"btn1-text","action":{"name":"select_item","context":{"itemId":"item-001","category":"electronics"}},"primary":true},
        {"id":"btn1-text","component":"Text","text":"Select Item 001"},
        {"id":"btn2","component":"Button","child":"btn2-text","action":{"name":"select_item","context":{"itemId":"item-002","category":"books"}}},
        {"id":"btn2-text","component":"Text","text":"Select Item 002"},
        {"id":"btn3","component":"Button","child":"btn3-text","action":{"name":"delete","context":{"target":"all","confirm":true}}},
        {"id":"btn3-text","component":"Text","text":"Delete All"}
      ]}}|
    ]
  end

  defp v09_string_format do
    # v0.9 native wire format with string_format function
    # Using heredoc to avoid delimiter conflicts with ${...} syntax
    components = """
    {"updateComponents":{"surfaceId":"v09-stringformat","components":[
      {"id":"root","component":"Column","children":["title","desc","ex1","ex2","ex3","ex4"]},
      {"id":"title","component":"Text","text":"v0.9 String Format","variant":"h4"},
      {"id":"desc","component":"Text","text":"The string_format function allows embedding data paths and function calls."},
      {"id":"ex1","component":"Text","text":{"call":"string_format","args":{"value":"Hello, ${/user/name}! You have ${/user/messageCount} messages."}}},
      {"id":"ex2","component":"Text","text":{"call":"string_format","args":{"value":"Current time: ${now()}"}}},
      {"id":"ex3","component":"Text","text":{"call":"string_format","args":{"value":"Order #${/order/id} - Total: $${/order/total}"}},"variant":"h4"},
      {"id":"ex4","component":"Card","child":"ex4-content"},
      {"id":"ex4-content","component":"Column","children":["ex4-greeting","ex4-status"]},
      {"id":"ex4-greeting","component":"Text","text":{"call":"string_format","args":{"value":"Welcome back, ${/user/name}!"}},"variant":"h3"},
      {"id":"ex4-status","component":"Text","text":{"call":"string_format","args":{"value":"Account: ${/user/accountType} - Points: ${/user/points}"}},"variant":"caption"}
    ]}}
    """

    create_surface =
      ~S({"createSurface":{"surfaceId":"v09-stringformat","catalogId":"https://a2ui.dev/specification/v0_9/standard_catalog.json"}})

    data =
      ~S({"updateDataModel":{"surfaceId":"v09-stringformat","path":"/","value":{"user":{"name":"Alice","messageCount":5,"accountType":"Premium","points":1250},"order":{"id":"ORD-12345","total":"99.99"}}}})

    [create_surface, String.trim(components), data]
  end

  # ============================================
  # Gallery Examples (from A2UI Composer)
  # ============================================

  defp gallery_flight_status do
    [
      ~S|{"surfaceUpdate":{"surfaceId":"gallery-flight","components":[{"id":"root","component":{"Card":{"child":"main-column"}}},{"id":"main-column","component":{"Column":{"children":{"explicitList":["header-row","route-row","divider","times-row"]},"gap":"small","alignment":"stretch"}}},{"id":"header-row","component":{"Row":{"children":{"explicitList":["header-left","date"]},"distribution":"spaceBetween","alignment":"center"}}},{"id":"header-left","component":{"Row":{"children":{"explicitList":["flight-indicator","flight-number"]},"gap":"small","alignment":"center"}}},{"id":"flight-indicator","component":{"Icon":{"name":{"literalString":"flight"}}}},{"id":"flight-number","component":{"Text":{"text":{"path":"/flightNumber"},"usageHint":"h3"}}},{"id":"date","component":{"Text":{"text":{"path":"/date"},"usageHint":"caption"}}},{"id":"route-row","component":{"Row":{"children":{"explicitList":["origin","arrow","destination"]},"gap":"small","alignment":"center"}}},{"id":"origin","component":{"Text":{"text":{"path":"/origin"},"usageHint":"h2"}}},{"id":"arrow","component":{"Text":{"text":{"literalString":"→"},"usageHint":"h2"}}},{"id":"destination","component":{"Text":{"text":{"path":"/destination"},"usageHint":"h2"}}},{"id":"divider","component":{"Divider":{}}},{"id":"times-row","component":{"Row":{"children":{"explicitList":["departure-col","status-col","arrival-col"]},"distribution":"spaceBetween"}}},{"id":"departure-col","component":{"Column":{"children":{"explicitList":["departure-label","departure-time"]},"alignment":"start","gap":"none"}}},{"id":"departure-label","component":{"Text":{"text":{"literalString":"Departs"},"usageHint":"caption"}}},{"id":"departure-time","component":{"Text":{"text":{"path":"/departureTime"},"usageHint":"h3"}}},{"id":"status-col","component":{"Column":{"children":{"explicitList":["status-label","status-value"]},"alignment":"center","gap":"none"}}},{"id":"status-label","component":{"Text":{"text":{"literalString":"Status"},"usageHint":"caption"}}},{"id":"status-value","component":{"Text":{"text":{"path":"/status"},"usageHint":"body"}}},{"id":"arrival-col","component":{"Column":{"children":{"explicitList":["arrival-label","arrival-time"]},"alignment":"end","gap":"none"}}},{"id":"arrival-label","component":{"Text":{"text":{"literalString":"Arrives"},"usageHint":"caption"}}},{"id":"arrival-time","component":{"Text":{"text":{"path":"/arrivalTime"},"usageHint":"h3"}}}]}}|,
      ~S|{"dataModelUpdate":{"surfaceId":"gallery-flight","contents":[{"key":"flightNumber","valueString":"OS 87"},{"key":"date","valueString":"Mon, Dec 15"},{"key":"origin","valueString":"Vienna"},{"key":"destination","valueString":"New York"},{"key":"departureTime","valueString":"10:15 AM"},{"key":"status","valueString":"On Time"},{"key":"arrivalTime","valueString":"2:30 PM"}]}}|,
      ~s({"beginRendering":{"surfaceId":"gallery-flight","root":"root"}})
    ]
  end

  defp gallery_notification do
    [
      ~S|{"surfaceUpdate":{"surfaceId":"gallery-notification","components":[{"id":"root","component":{"Card":{"child":"main-column"}}},{"id":"main-column","component":{"Column":{"children":{"explicitList":["icon","title","description","actions"]},"gap":"medium","alignment":"center"}}},{"id":"icon","component":{"Icon":{"name":{"path":"/icon"}}}},{"id":"title","component":{"Text":{"text":{"path":"/title"},"usageHint":"h3"}}},{"id":"description","component":{"Text":{"text":{"path":"/description"},"usageHint":"body"}}},{"id":"actions","component":{"Row":{"children":{"explicitList":["yes-btn","no-btn"]},"gap":"medium","distribution":"center"}}},{"id":"yes-btn-text","component":{"Text":{"text":{"literalString":"Yes"}}}},{"id":"yes-btn","component":{"Button":{"child":"yes-btn-text","action":"accept"}}},{"id":"no-btn-text","component":{"Text":{"text":{"literalString":"No"}}}},{"id":"no-btn","component":{"Button":{"child":"no-btn-text","action":"decline"}}}]}}|,
      ~S|{"dataModelUpdate":{"surfaceId":"gallery-notification","contents":[{"key":"icon","valueString":"check"},{"key":"title","valueString":"Enable notifications"},{"key":"description","valueString":"Get alerts for order status changes"}]}}|,
      ~s({"beginRendering":{"surfaceId":"gallery-notification","root":"root"}})
    ]
  end

  defp gallery_movie_card do
    [
      ~S|{"surfaceUpdate":{"surfaceId":"gallery-movie","components":[{"id":"root","component":{"Card":{"child":"main-column"}}},{"id":"main-column","component":{"Column":{"children":{"explicitList":["poster","content"]},"gap":"small"}}},{"id":"poster","component":{"Image":{"url":{"path":"/poster"},"fit":"cover"}}},{"id":"content","component":{"Column":{"children":{"explicitList":["title-row","genre","rating-row","runtime"]},"gap":"small"}}},{"id":"title-row","component":{"Row":{"children":{"explicitList":["movie-title","year"]},"gap":"small","alignment":"center"}}},{"id":"movie-title","component":{"Text":{"text":{"path":"/title"},"usageHint":"h3"}}},{"id":"year","component":{"Text":{"text":{"path":"/year"},"usageHint":"caption"}}},{"id":"genre","component":{"Text":{"text":{"path":"/genre"},"usageHint":"caption"}}},{"id":"rating-row","component":{"Row":{"children":{"explicitList":["star-icon","rating-value"]},"gap":"small","alignment":"center"}}},{"id":"star-icon","component":{"Icon":{"name":{"literalString":"star"}}}},{"id":"rating-value","component":{"Text":{"text":{"path":"/rating"},"usageHint":"body"}}},{"id":"runtime","component":{"Row":{"children":{"explicitList":["time-icon","runtime-text"]},"gap":"small","alignment":"center"}}},{"id":"time-icon","component":{"Icon":{"name":{"literalString":"schedule"}}}},{"id":"runtime-text","component":{"Text":{"text":{"path":"/runtime"},"usageHint":"caption"}}}]}}|,
      ~S|{"dataModelUpdate":{"surfaceId":"gallery-movie","contents":[{"key":"poster","valueString":"https://images.unsplash.com/photo-1536440136628-849c177e76a1?w=200&h=300&fit=crop"},{"key":"title","valueString":"Interstellar"},{"key":"year","valueString":"(2014)"},{"key":"genre","valueString":"Sci-Fi • Adventure • Drama"},{"key":"rating","valueString":"8.7/10"},{"key":"runtime","valueString":"2h 49min"}]}}|,
      ~s({"beginRendering":{"surfaceId":"gallery-movie","root":"root"}})
    ]
  end

  defp gallery_weather do
    # Using v0.9 format for nested forecast data
    [
      ~S|{"surfaceUpdate":{"surfaceId":"gallery-weather","components":[{"id":"root","component":{"Card":{"child":"main-column"}}},{"id":"main-column","component":{"Column":{"children":{"explicitList":["temp-row","location","description","forecast-row"]},"gap":"small","alignment":"center"}}},{"id":"temp-row","component":{"Row":{"children":{"explicitList":["temp-high","temp-low"]},"gap":"small","alignment":"baseline"}}},{"id":"temp-high","component":{"Text":{"text":{"path":"/tempHigh"},"usageHint":"h1"}}},{"id":"temp-low","component":{"Text":{"text":{"path":"/tempLow"},"usageHint":"h2"}}},{"id":"location","component":{"Text":{"text":{"path":"/location"},"usageHint":"h3"}}},{"id":"description","component":{"Text":{"text":{"path":"/description"},"usageHint":"caption"}}},{"id":"forecast-row","component":{"Row":{"children":{"explicitList":["day1","day2","day3","day4","day5"]},"distribution":"spaceAround","gap":"small"}}},{"id":"day1","component":{"Column":{"children":{"explicitList":["day1-icon","day1-temp"]},"alignment":"center"}}},{"id":"day1-icon","component":{"Text":{"text":{"path":"/forecast/0/icon"},"usageHint":"h3"}}},{"id":"day1-temp","component":{"Text":{"text":{"path":"/forecast/0/temp"},"usageHint":"caption"}}},{"id":"day2","component":{"Column":{"children":{"explicitList":["day2-icon","day2-temp"]},"alignment":"center"}}},{"id":"day2-icon","component":{"Text":{"text":{"path":"/forecast/1/icon"},"usageHint":"h3"}}},{"id":"day2-temp","component":{"Text":{"text":{"path":"/forecast/1/temp"},"usageHint":"caption"}}},{"id":"day3","component":{"Column":{"children":{"explicitList":["day3-icon","day3-temp"]},"alignment":"center"}}},{"id":"day3-icon","component":{"Text":{"text":{"path":"/forecast/2/icon"},"usageHint":"h3"}}},{"id":"day3-temp","component":{"Text":{"text":{"path":"/forecast/2/temp"},"usageHint":"caption"}}},{"id":"day4","component":{"Column":{"children":{"explicitList":["day4-icon","day4-temp"]},"alignment":"center"}}},{"id":"day4-icon","component":{"Text":{"text":{"path":"/forecast/3/icon"},"usageHint":"h3"}}},{"id":"day4-temp","component":{"Text":{"text":{"path":"/forecast/3/temp"},"usageHint":"caption"}}},{"id":"day5","component":{"Column":{"children":{"explicitList":["day5-icon","day5-temp"]},"alignment":"center"}}},{"id":"day5-icon","component":{"Text":{"text":{"path":"/forecast/4/icon"},"usageHint":"h3"}}},{"id":"day5-temp","component":{"Text":{"text":{"path":"/forecast/4/temp"},"usageHint":"caption"}}}]}}|,
      ~S|{"dataModelUpdate":{"surfaceId":"gallery-weather","contents":[{"key":"tempHigh","valueString":"72°"},{"key":"tempLow","valueString":"58°"},{"key":"location","valueString":"Austin, TX"},{"key":"description","valueString":"Clear skies with light breeze"}]}}|,
      ~S|{"updateDataModel":{"surfaceId":"gallery-weather","path":"/forecast","value":{"0":{"icon":"☀️","temp":"74°"},"1":{"icon":"☀️","temp":"76°"},"2":{"icon":"⛅","temp":"71°"},"3":{"icon":"☀️","temp":"73°"},"4":{"icon":"☀️","temp":"75°"}}}}|,
      ~s({"beginRendering":{"surfaceId":"gallery-weather","root":"root"}})
    ]
  end

  defp gallery_task_card do
    [
      ~S|{"surfaceUpdate":{"surfaceId":"gallery-task","components":[{"id":"root","component":{"Card":{"child":"main-row"}}},{"id":"main-row","component":{"Row":{"children":{"explicitList":["content","priority"]},"gap":"medium","alignment":"start"}}},{"id":"content","component":{"Column":{"children":{"explicitList":["title","description","meta-row"]},"gap":"small"}}},{"id":"title","component":{"Text":{"text":{"path":"/title"},"usageHint":"h3"}}},{"id":"description","component":{"Text":{"text":{"path":"/description"},"usageHint":"body"}}},{"id":"meta-row","component":{"Row":{"children":{"explicitList":["due-date","project"]},"gap":"medium"}}},{"id":"due-date","component":{"Text":{"text":{"path":"/dueDate"},"usageHint":"caption"}}},{"id":"project","component":{"Text":{"text":{"path":"/project"},"usageHint":"caption"}}},{"id":"priority","component":{"Icon":{"name":{"path":"/priorityIcon"}}}}]}}|,
      ~S|{"dataModelUpdate":{"surfaceId":"gallery-task","contents":[{"key":"title","valueString":"Review pull request"},{"key":"description","valueString":"Review and approve the authentication module changes."},{"key":"dueDate","valueString":"Today"},{"key":"project","valueString":"Backend"},{"key":"priorityIcon","valueString":"error"}]}}|,
      ~s({"beginRendering":{"surfaceId":"gallery-task","root":"root"}})
    ]
  end

  defp gallery_stats_card do
    [
      ~S|{"surfaceUpdate":{"surfaceId":"gallery-stats","components":[{"id":"root","component":{"Card":{"child":"main-column"}}},{"id":"main-column","component":{"Column":{"children":{"explicitList":["header","value","trend-row"]},"gap":"small"}}},{"id":"header","component":{"Row":{"children":{"explicitList":["metric-icon","metric-name"]},"gap":"small","alignment":"center"}}},{"id":"metric-icon","component":{"Icon":{"name":{"path":"/icon"}}}},{"id":"metric-name","component":{"Text":{"text":{"path":"/metricName"},"usageHint":"caption"}}},{"id":"value","component":{"Text":{"text":{"path":"/value"},"usageHint":"h1"}}},{"id":"trend-row","component":{"Row":{"children":{"explicitList":["trend-icon","trend-text"]},"gap":"small","alignment":"center"}}},{"id":"trend-icon","component":{"Icon":{"name":{"path":"/trendIcon"}}}},{"id":"trend-text","component":{"Text":{"text":{"path":"/trendText"},"usageHint":"body"}}}]}}|,
      ~S|{"dataModelUpdate":{"surfaceId":"gallery-stats","contents":[{"key":"icon","valueString":"star"},{"key":"metricName","valueString":"Monthly Revenue"},{"key":"value","valueString":"$48,294"},{"key":"trendIcon","valueString":"arrowForward"},{"key":"trendText","valueString":"+12.5% from last month"}]}}|,
      ~s({"beginRendering":{"surfaceId":"gallery-stats","root":"root"}})
    ]
  end

  defp gallery_account_balance do
    [
      ~S|{"surfaceUpdate":{"surfaceId":"gallery-account","components":[{"id":"root","component":{"Card":{"child":"main-column"}}},{"id":"main-column","component":{"Column":{"children":{"explicitList":["header","balance","updated","divider","actions"]},"gap":"medium"}}},{"id":"header","component":{"Row":{"children":{"explicitList":["account-icon","account-name"]},"gap":"small","alignment":"center"}}},{"id":"account-icon","component":{"Icon":{"name":{"literalString":"payment"}}}},{"id":"account-name","component":{"Text":{"text":{"path":"/accountName"},"usageHint":"h4"}}},{"id":"balance","component":{"Text":{"text":{"path":"/balance"},"usageHint":"h1"}}},{"id":"updated","component":{"Text":{"text":{"path":"/lastUpdated"},"usageHint":"caption"}}},{"id":"divider","component":{"Divider":{}}},{"id":"actions","component":{"Row":{"children":{"explicitList":["transfer-btn","pay-btn"]},"gap":"small"}}},{"id":"transfer-btn-text","component":{"Text":{"text":{"literalString":"Transfer"}}}},{"id":"transfer-btn","component":{"Button":{"child":"transfer-btn-text","action":"transfer"}}},{"id":"pay-btn-text","component":{"Text":{"text":{"literalString":"Pay Bill"}}}},{"id":"pay-btn","component":{"Button":{"child":"pay-btn-text","action":"pay_bill"}}}]}}|,
      ~S|{"dataModelUpdate":{"surfaceId":"gallery-account","contents":[{"key":"accountName","valueString":"Primary Checking"},{"key":"balance","valueString":"$12,458.32"},{"key":"lastUpdated","valueString":"Updated just now"}]}}|,
      ~s({"beginRendering":{"surfaceId":"gallery-account","root":"root"}})
    ]
  end

  defp gallery_step_counter do
    [
      ~S|{"surfaceUpdate":{"surfaceId":"gallery-steps","components":[{"id":"root","component":{"Card":{"child":"main-column"}}},{"id":"main-column","component":{"Column":{"children":{"explicitList":["header","steps-display","goal-text","divider","stats-row"]},"gap":"medium","alignment":"center"}}},{"id":"header","component":{"Row":{"children":{"explicitList":["steps-icon","title"]},"gap":"small","alignment":"center"}}},{"id":"steps-icon","component":{"Icon":{"name":{"literalString":"person"}}}},{"id":"title","component":{"Text":{"text":{"literalString":"Today's Steps"},"usageHint":"h4"}}},{"id":"steps-display","component":{"Text":{"text":{"path":"/steps"},"usageHint":"h1"}}},{"id":"goal-text","component":{"Text":{"text":{"path":"/goalProgress"},"usageHint":"body"}}},{"id":"divider","component":{"Divider":{}}},{"id":"stats-row","component":{"Row":{"children":{"explicitList":["distance-col","calories-col"]},"distribution":"spaceAround"}}},{"id":"distance-col","component":{"Column":{"children":{"explicitList":["distance-value","distance-label"]},"alignment":"center"}}},{"id":"distance-value","component":{"Text":{"text":{"path":"/distance"},"usageHint":"h3"}}},{"id":"distance-label","component":{"Text":{"text":{"literalString":"Distance"},"usageHint":"caption"}}},{"id":"calories-col","component":{"Column":{"children":{"explicitList":["calories-value","calories-label"]},"alignment":"center"}}},{"id":"calories-value","component":{"Text":{"text":{"path":"/calories"},"usageHint":"h3"}}},{"id":"calories-label","component":{"Text":{"text":{"literalString":"Calories"},"usageHint":"caption"}}}]}}|,
      ~S|{"dataModelUpdate":{"surfaceId":"gallery-steps","contents":[{"key":"steps","valueString":"8,432"},{"key":"goalProgress","valueString":"84% of 10,000 goal"},{"key":"distance","valueString":"3.8 mi"},{"key":"calories","valueString":"312"}]}}|,
      ~s({"beginRendering":{"surfaceId":"gallery-steps","root":"root"}})
    ]
  end

  defp gallery_countdown_timer do
    [
      ~S|{"surfaceUpdate":{"surfaceId":"gallery-countdown","components":[{"id":"root","component":{"Card":{"child":"main-column"}}},{"id":"main-column","component":{"Column":{"children":{"explicitList":["event-name","countdown-row","target-date"]},"gap":"medium","alignment":"center"}}},{"id":"event-name","component":{"Text":{"text":{"path":"/eventName"},"usageHint":"h3"}}},{"id":"countdown-row","component":{"Row":{"children":{"explicitList":["days-col","hours-col","minutes-col"]},"distribution":"spaceAround"}}},{"id":"days-col","component":{"Column":{"children":{"explicitList":["days-value","days-label"]},"alignment":"center"}}},{"id":"days-value","component":{"Text":{"text":{"path":"/days"},"usageHint":"h1"}}},{"id":"days-label","component":{"Text":{"text":{"literalString":"Days"},"usageHint":"caption"}}},{"id":"hours-col","component":{"Column":{"children":{"explicitList":["hours-value","hours-label"]},"alignment":"center"}}},{"id":"hours-value","component":{"Text":{"text":{"path":"/hours"},"usageHint":"h1"}}},{"id":"hours-label","component":{"Text":{"text":{"literalString":"Hours"},"usageHint":"caption"}}},{"id":"minutes-col","component":{"Column":{"children":{"explicitList":["minutes-value","minutes-label"]},"alignment":"center"}}},{"id":"minutes-value","component":{"Text":{"text":{"path":"/minutes"},"usageHint":"h1"}}},{"id":"minutes-label","component":{"Text":{"text":{"literalString":"Minutes"},"usageHint":"caption"}}},{"id":"target-date","component":{"Text":{"text":{"path":"/targetDate"},"usageHint":"body"}}}]}}|,
      ~S|{"dataModelUpdate":{"surfaceId":"gallery-countdown","contents":[{"key":"eventName","valueString":"Product Launch"},{"key":"days","valueString":"14"},{"key":"hours","valueString":"08"},{"key":"minutes","valueString":"32"},{"key":"targetDate","valueString":"January 15, 2025"}]}}|,
      ~s({"beginRendering":{"surfaceId":"gallery-countdown","root":"root"}})
    ]
  end

  defp gallery_login_form do
    [
      ~S|{"surfaceUpdate":{"surfaceId":"gallery-login","components":[{"id":"root","component":{"Card":{"child":"main-column"}}},{"id":"main-column","component":{"Column":{"children":{"explicitList":["header","email-field","password-field","login-btn","divider","signup-text"]},"gap":"medium"}}},{"id":"header","component":{"Column":{"children":{"explicitList":["title","subtitle"]},"alignment":"center"}}},{"id":"title","component":{"Text":{"text":{"literalString":"Welcome back"},"usageHint":"h2"}}},{"id":"subtitle","component":{"Text":{"text":{"literalString":"Sign in to your account"},"usageHint":"caption"}}},{"id":"email-field","component":{"TextField":{"text":{"path":"/email"},"placeholder":{"literalString":"Email address"},"label":{"literalString":"Email"}}}},{"id":"password-field","component":{"TextField":{"text":{"path":"/password"},"placeholder":{"literalString":"Password"},"label":{"literalString":"Password"},"textFieldType":"obscured"}}},{"id":"login-btn-text","component":{"Text":{"text":{"literalString":"Sign in"}}}},{"id":"login-btn","component":{"Button":{"child":"login-btn-text","action":"login","primary":true}}},{"id":"divider","component":{"Divider":{}}},{"id":"signup-text","component":{"Row":{"children":{"explicitList":["no-account","signup-link"]},"distribution":"center","gap":"small"}}},{"id":"no-account","component":{"Text":{"text":{"literalString":"Don't have an account?"},"usageHint":"caption"}}},{"id":"signup-link-text","component":{"Text":{"text":{"literalString":"Sign up"}}}},{"id":"signup-link","component":{"Button":{"child":"signup-link-text","action":"signup"}}}]}}|,
      ~S|{"dataModelUpdate":{"surfaceId":"gallery-login","contents":[{"key":"email","valueString":""},{"key":"password","valueString":""}]}}|,
      ~s({"beginRendering":{"surfaceId":"gallery-login","root":"root"}})
    ]
  end

  defp gallery_contact_card do
    [
      ~S|{"surfaceUpdate":{"surfaceId":"gallery-contact","components":[{"id":"root","component":{"Card":{"child":"main-column"}}},{"id":"main-column","component":{"Column":{"children":{"explicitList":["avatar-image","name","title","divider","contact-info","actions"]},"gap":"medium","alignment":"center"}}},{"id":"avatar-image","component":{"Image":{"url":{"path":"/avatar"},"fit":"cover","usageHint":"avatar"}}},{"id":"name","component":{"Text":{"text":{"path":"/name"},"usageHint":"h2"}}},{"id":"title","component":{"Text":{"text":{"path":"/title"},"usageHint":"body"}}},{"id":"divider","component":{"Divider":{}}},{"id":"contact-info","component":{"Column":{"children":{"explicitList":["phone-row","email-row","location-row"]},"gap":"small"}}},{"id":"phone-row","component":{"Row":{"children":{"explicitList":["phone-icon","phone-text"]},"gap":"small","alignment":"center"}}},{"id":"phone-icon","component":{"Icon":{"name":{"literalString":"phone"}}}},{"id":"phone-text","component":{"Text":{"text":{"path":"/phone"},"usageHint":"body"}}},{"id":"email-row","component":{"Row":{"children":{"explicitList":["email-icon","email-text"]},"gap":"small","alignment":"center"}}},{"id":"email-icon","component":{"Icon":{"name":{"literalString":"mail"}}}},{"id":"email-text","component":{"Text":{"text":{"path":"/email"},"usageHint":"body"}}},{"id":"location-row","component":{"Row":{"children":{"explicitList":["location-icon","location-text"]},"gap":"small","alignment":"center"}}},{"id":"location-icon","component":{"Icon":{"name":{"literalString":"locationOn"}}}},{"id":"location-text","component":{"Text":{"text":{"path":"/location"},"usageHint":"body"}}},{"id":"actions","component":{"Row":{"children":{"explicitList":["call-btn","message-btn"]},"gap":"small"}}},{"id":"call-btn-text","component":{"Text":{"text":{"literalString":"Call"}}}},{"id":"call-btn","component":{"Button":{"child":"call-btn-text","action":"call"}}},{"id":"message-btn-text","component":{"Text":{"text":{"literalString":"Message"}}}},{"id":"message-btn","component":{"Button":{"child":"message-btn-text","action":"message"}}}]}}|,
      ~S|{"dataModelUpdate":{"surfaceId":"gallery-contact","contents":[{"key":"avatar","valueString":"https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=200&h=200&fit=crop"},{"key":"name","valueString":"David Park"},{"key":"title","valueString":"Engineering Manager"},{"key":"phone","valueString":"+1 (555) 234-5678"},{"key":"email","valueString":"david.park@company.com"},{"key":"location","valueString":"San Francisco, CA"}]}}|,
      ~s({"beginRendering":{"surfaceId":"gallery-contact","root":"root"}})
    ]
  end

  defp gallery_user_profile do
    [
      ~S|{"surfaceUpdate":{"surfaceId":"gallery-profile","components":[{"id":"root","component":{"Card":{"child":"main-column"}}},{"id":"main-column","component":{"Column":{"children":{"explicitList":["header","info","bio","stats-row","follow-btn"]},"gap":"medium","alignment":"center"}}},{"id":"header","component":{"Image":{"url":{"path":"/avatar"},"fit":"cover","usageHint":"avatar"}}},{"id":"info","component":{"Column":{"children":{"explicitList":["name","username"]},"alignment":"center"}}},{"id":"name","component":{"Text":{"text":{"path":"/name"},"usageHint":"h2"}}},{"id":"username","component":{"Text":{"text":{"path":"/username"},"usageHint":"caption"}}},{"id":"bio","component":{"Text":{"text":{"path":"/bio"},"usageHint":"body"}}},{"id":"stats-row","component":{"Row":{"children":{"explicitList":["followers-col","following-col","posts-col"]},"distribution":"spaceAround"}}},{"id":"followers-col","component":{"Column":{"children":{"explicitList":["followers-count","followers-label"]},"alignment":"center"}}},{"id":"followers-count","component":{"Text":{"text":{"path":"/followers"},"usageHint":"h3"}}},{"id":"followers-label","component":{"Text":{"text":{"literalString":"Followers"},"usageHint":"caption"}}},{"id":"following-col","component":{"Column":{"children":{"explicitList":["following-count","following-label"]},"alignment":"center"}}},{"id":"following-count","component":{"Text":{"text":{"path":"/following"},"usageHint":"h3"}}},{"id":"following-label","component":{"Text":{"text":{"literalString":"Following"},"usageHint":"caption"}}},{"id":"posts-col","component":{"Column":{"children":{"explicitList":["posts-count","posts-label"]},"alignment":"center"}}},{"id":"posts-count","component":{"Text":{"text":{"path":"/posts"},"usageHint":"h3"}}},{"id":"posts-label","component":{"Text":{"text":{"literalString":"Posts"},"usageHint":"caption"}}},{"id":"follow-btn-text","component":{"Text":{"text":{"path":"/followText"}}}},{"id":"follow-btn","component":{"Button":{"child":"follow-btn-text","action":"follow","primary":true}}}]}}|,
      ~S|{"dataModelUpdate":{"surfaceId":"gallery-profile","contents":[{"key":"avatar","valueString":"https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=200&h=200&fit=crop"},{"key":"name","valueString":"Sarah Chen"},{"key":"username","valueString":"@sarahchen"},{"key":"bio","valueString":"Product Designer at Tech Co. Creating delightful experiences."},{"key":"followers","valueString":"12.4K"},{"key":"following","valueString":"892"},{"key":"posts","valueString":"347"},{"key":"followText","valueString":"Follow"}]}}|,
      ~s({"beginRendering":{"surfaceId":"gallery-profile","root":"root"}})
    ]
  end

  defp gallery_product_card do
    [
      ~S|{"surfaceUpdate":{"surfaceId":"gallery-product","components":[{"id":"root","component":{"Card":{"child":"main-column"}}},{"id":"main-column","component":{"Column":{"children":{"explicitList":["image","details"]},"gap":"small"}}},{"id":"image","component":{"Image":{"url":{"path":"/imageUrl"},"fit":"cover"}}},{"id":"details","component":{"Column":{"children":{"explicitList":["name","rating-row","price-row","actions"]},"gap":"small"}}},{"id":"name","component":{"Text":{"text":{"path":"/name"},"usageHint":"h3"}}},{"id":"rating-row","component":{"Row":{"children":{"explicitList":["stars","reviews"]},"gap":"small","alignment":"center"}}},{"id":"stars","component":{"Text":{"text":{"path":"/stars"},"usageHint":"body"}}},{"id":"reviews","component":{"Text":{"text":{"path":"/reviews"},"usageHint":"caption"}}},{"id":"price-row","component":{"Row":{"children":{"explicitList":["price","original-price"]},"gap":"small","alignment":"baseline"}}},{"id":"price","component":{"Text":{"text":{"path":"/price"},"usageHint":"h2"}}},{"id":"original-price","component":{"Text":{"text":{"path":"/originalPrice"},"usageHint":"caption"}}},{"id":"actions","component":{"Row":{"children":{"explicitList":["add-cart-btn"]},"gap":"small"}}},{"id":"add-cart-btn-text","component":{"Text":{"text":{"literalString":"Add to Cart"}}}},{"id":"add-cart-btn","component":{"Button":{"child":"add-cart-btn-text","action":"addToCart","primary":true}}}]}}|,
      ~S|{"dataModelUpdate":{"surfaceId":"gallery-product","contents":[{"key":"imageUrl","valueString":"https://images.unsplash.com/photo-1505740420928-5e560c06d30e?w=300&h=200&fit=crop"},{"key":"name","valueString":"Wireless Headphones Pro"},{"key":"stars","valueString":"★★★★★"},{"key":"reviews","valueString":"(2,847 reviews)"},{"key":"price","valueString":"$199.99"},{"key":"originalPrice","valueString":"$249.99"}]}}|,
      ~s({"beginRendering":{"surfaceId":"gallery-product","root":"root"}})
    ]
  end

  defp gallery_podcast_episode do
    [
      ~S|{"surfaceUpdate":{"surfaceId":"gallery-podcast","components":[{"id":"root","component":{"Card":{"child":"main-row"}}},{"id":"main-row","component":{"Row":{"children":{"explicitList":["artwork","content"]},"gap":"medium","alignment":"start"}}},{"id":"artwork","component":{"Image":{"url":{"path":"/artwork"},"fit":"cover","usageHint":"smallFeature"}}},{"id":"content","component":{"Column":{"children":{"explicitList":["show-name","episode-title","meta-row","description","play-btn"]},"gap":"small"}}},{"id":"show-name","component":{"Text":{"text":{"path":"/showName"},"usageHint":"caption"}}},{"id":"episode-title","component":{"Text":{"text":{"path":"/episodeTitle"},"usageHint":"h4"}}},{"id":"meta-row","component":{"Row":{"children":{"explicitList":["duration","date"]},"gap":"medium"}}},{"id":"duration","component":{"Text":{"text":{"path":"/duration"},"usageHint":"caption"}}},{"id":"date","component":{"Text":{"text":{"path":"/date"},"usageHint":"caption"}}},{"id":"description","component":{"Text":{"text":{"path":"/description"},"usageHint":"body"}}},{"id":"play-btn-text","component":{"Text":{"text":{"literalString":"Play Episode"}}}},{"id":"play-btn","component":{"Button":{"child":"play-btn-text","action":"play","primary":true}}}]}}|,
      ~S|{"dataModelUpdate":{"surfaceId":"gallery-podcast","contents":[{"key":"artwork","valueString":"https://images.unsplash.com/photo-1478737270239-2f02b77fc618?w=128&h=128&fit=crop"},{"key":"showName","valueString":"Tech Talk Daily"},{"key":"episodeTitle","valueString":"The Future of AI in Product Design"},{"key":"duration","valueString":"45 min"},{"key":"date","valueString":"Dec 15, 2024"},{"key":"description","valueString":"How AI is transforming the way we design and build products."}]}}|,
      ~s({"beginRendering":{"surfaceId":"gallery-podcast","root":"root"}})
    ]
  end

  defp gallery_purchase_complete do
    [
      ~S|{"surfaceUpdate":{"surfaceId":"gallery-purchase","components":[{"id":"root","component":{"Card":{"child":"main-column"}}},{"id":"main-column","component":{"Column":{"children":{"explicitList":["success-icon","title","product-row","divider","details-col","view-btn"]},"gap":"medium","alignment":"center"}}},{"id":"success-icon","component":{"Icon":{"name":{"literalString":"check"}}}},{"id":"title","component":{"Text":{"text":{"literalString":"Purchase Complete"},"usageHint":"h2"}}},{"id":"product-row","component":{"Row":{"children":{"explicitList":["product-image","product-info"]},"gap":"medium","alignment":"center"}}},{"id":"product-image","component":{"Image":{"url":{"path":"/productImage"},"fit":"cover","usageHint":"smallFeature"}}},{"id":"product-info","component":{"Column":{"children":{"explicitList":["product-name","product-price"]},"gap":"small"}}},{"id":"product-name","component":{"Text":{"text":{"path":"/productName"},"usageHint":"h4"}}},{"id":"product-price","component":{"Text":{"text":{"path":"/price"},"usageHint":"body"}}},{"id":"divider","component":{"Divider":{}}},{"id":"details-col","component":{"Column":{"children":{"explicitList":["delivery-row","seller-row"]},"gap":"small"}}},{"id":"delivery-row","component":{"Row":{"children":{"explicitList":["delivery-icon","delivery-text"]},"gap":"small","alignment":"center"}}},{"id":"delivery-icon","component":{"Icon":{"name":{"literalString":"arrowForward"}}}},{"id":"delivery-text","component":{"Text":{"text":{"path":"/deliveryDate"},"usageHint":"body"}}},{"id":"seller-row","component":{"Row":{"children":{"explicitList":["seller-label","seller-name"]},"gap":"small"}}},{"id":"seller-label","component":{"Text":{"text":{"literalString":"Sold by:"},"usageHint":"caption"}}},{"id":"seller-name","component":{"Text":{"text":{"path":"/seller"},"usageHint":"body"}}},{"id":"view-btn-text","component":{"Text":{"text":{"literalString":"View Order Details"}}}},{"id":"view-btn","component":{"Button":{"child":"view-btn-text","action":"view_details","primary":true}}}]}}|,
      ~S|{"dataModelUpdate":{"surfaceId":"gallery-purchase","contents":[{"key":"productImage","valueString":"https://images.unsplash.com/photo-1505740420928-5e560c06d30e?w=100&h=100&fit=crop"},{"key":"productName","valueString":"Wireless Headphones Pro"},{"key":"price","valueString":"$199.99"},{"key":"deliveryDate","valueString":"Arrives Dec 18 - Dec 20"},{"key":"seller","valueString":"TechStore Official"}]}}|,
      ~s({"beginRendering":{"surfaceId":"gallery-purchase","root":"root"}})
    ]
  end

  defp gallery_shipping_status do
    [
      ~S|{"surfaceUpdate":{"surfaceId":"gallery-shipping","components":[{"id":"root","component":{"Card":{"child":"main-column"}}},{"id":"main-column","component":{"Column":{"children":{"explicitList":["header","tracking-number","divider","steps","eta"]},"gap":"medium"}}},{"id":"header","component":{"Row":{"children":{"explicitList":["package-icon","title"]},"gap":"small","alignment":"center"}}},{"id":"package-icon","component":{"Icon":{"name":{"literalString":"shoppingCart"}}}},{"id":"title","component":{"Text":{"text":{"literalString":"Package Status"},"usageHint":"h3"}}},{"id":"tracking-number","component":{"Text":{"text":{"path":"/trackingNumber"},"usageHint":"caption"}}},{"id":"divider","component":{"Divider":{}}},{"id":"steps","component":{"Column":{"children":{"explicitList":["step1","step2","step3","step4"]},"gap":"small"}}},{"id":"step1","component":{"Row":{"children":{"explicitList":["step1-icon","step1-text"]},"gap":"small","alignment":"center"}}},{"id":"step1-icon","component":{"Icon":{"name":{"literalString":"check"}}}},{"id":"step1-text","component":{"Text":{"text":{"literalString":"Order Placed"},"usageHint":"body"}}},{"id":"step2","component":{"Row":{"children":{"explicitList":["step2-icon","step2-text"]},"gap":"small","alignment":"center"}}},{"id":"step2-icon","component":{"Icon":{"name":{"literalString":"check"}}}},{"id":"step2-text","component":{"Text":{"text":{"literalString":"Shipped"},"usageHint":"body"}}},{"id":"step3","component":{"Row":{"children":{"explicitList":["step3-icon","step3-text"]},"gap":"small","alignment":"center"}}},{"id":"step3-icon","component":{"Icon":{"name":{"literalString":"arrowForward"}}}},{"id":"step3-text","component":{"Text":{"text":{"literalString":"Out for Delivery"},"usageHint":"h4"}}},{"id":"step4","component":{"Row":{"children":{"explicitList":["step4-icon","step4-text"]},"gap":"small","alignment":"center"}}},{"id":"step4-icon","component":{"Icon":{"name":{"literalString":"home"}}}},{"id":"step4-text","component":{"Text":{"text":{"literalString":"Delivered"},"usageHint":"caption"}}},{"id":"eta","component":{"Row":{"children":{"explicitList":["eta-icon","eta-text"]},"gap":"small","alignment":"center"}}},{"id":"eta-icon","component":{"Icon":{"name":{"literalString":"clock"}}}},{"id":"eta-text","component":{"Text":{"text":{"path":"/eta"},"usageHint":"body"}}}]}}|,
      ~S|{"dataModelUpdate":{"surfaceId":"gallery-shipping","contents":[{"key":"trackingNumber","valueString":"Tracking: 1Z999AA10123456784"},{"key":"eta","valueString":"Estimated delivery: Today by 8 PM"}]}}|,
      ~s({"beginRendering":{"surfaceId":"gallery-shipping","root":"root"}})
    ]
  end

  defp gallery_calendar_day do
    [
      ~S|{"surfaceUpdate":{"surfaceId":"gallery-calendar","components":[{"id":"root","component":{"Card":{"child":"main-column"}}},{"id":"main-column","component":{"Column":{"children":{"explicitList":["header-row","divider","actions"]},"gap":"small"}}},{"id":"header-row","component":{"Row":{"children":{"explicitList":["date-col","events-col"]},"gap":"medium"}}},{"id":"date-col","component":{"Column":{"children":{"explicitList":["day-name","day-number"]},"alignment":"start"}}},{"id":"day-name","component":{"Text":{"text":{"path":"/dayName"},"usageHint":"caption"}}},{"id":"day-number","component":{"Text":{"text":{"path":"/dayNumber"},"usageHint":"h1"}}},{"id":"events-col","component":{"Column":{"children":{"explicitList":["event1","event2","event3"]},"gap":"small"}}},{"id":"event1","component":{"Column":{"children":{"explicitList":["event1-title","event1-time"]}}}},{"id":"event1-title","component":{"Text":{"text":{"path":"/event1Title"},"usageHint":"body"}}},{"id":"event1-time","component":{"Text":{"text":{"path":"/event1Time"},"usageHint":"caption"}}},{"id":"event2","component":{"Column":{"children":{"explicitList":["event2-title","event2-time"]}}}},{"id":"event2-title","component":{"Text":{"text":{"path":"/event2Title"},"usageHint":"body"}}},{"id":"event2-time","component":{"Text":{"text":{"path":"/event2Time"},"usageHint":"caption"}}},{"id":"event3","component":{"Column":{"children":{"explicitList":["event3-title","event3-time"]}}}},{"id":"event3-title","component":{"Text":{"text":{"path":"/event3Title"},"usageHint":"body"}}},{"id":"event3-time","component":{"Text":{"text":{"path":"/event3Time"},"usageHint":"caption"}}},{"id":"divider","component":{"Divider":{}}},{"id":"actions","component":{"Row":{"children":{"explicitList":["add-btn","discard-btn"]},"gap":"small"}}},{"id":"add-btn-text","component":{"Text":{"text":{"literalString":"Add to calendar"}}}},{"id":"add-btn","component":{"Button":{"child":"add-btn-text","action":"add"}}},{"id":"discard-btn-text","component":{"Text":{"text":{"literalString":"Discard"}}}},{"id":"discard-btn","component":{"Button":{"child":"discard-btn-text","action":"discard"}}}]}}|,
      ~S|{"dataModelUpdate":{"surfaceId":"gallery-calendar","contents":[{"key":"dayName","valueString":"Friday"},{"key":"dayNumber","valueString":"28"},{"key":"event1Title","valueString":"Lunch"},{"key":"event1Time","valueString":"12:00 - 12:45 PM"},{"key":"event2Title","valueString":"Q1 roadmap review"},{"key":"event2Time","valueString":"1:00 - 2:00 PM"},{"key":"event3Title","valueString":"Team standup"},{"key":"event3Time","valueString":"3:30 - 4:00 PM"}]}}|,
      ~s({"beginRendering":{"surfaceId":"gallery-calendar","root":"root"}})
    ]
  end

  defp gallery_chat_thread do
    [
      ~S|{"surfaceUpdate":{"surfaceId":"gallery-chat","components":[{"id":"root","component":{"Card":{"child":"main-column"}}},{"id":"main-column","component":{"Column":{"children":{"explicitList":["header","divider","messages"]},"gap":"small"}}},{"id":"header","component":{"Row":{"children":{"explicitList":["channel-icon","channel-name"]},"gap":"small","alignment":"center"}}},{"id":"channel-icon","component":{"Text":{"text":{"literalString":"#"},"usageHint":"h3"}}},{"id":"channel-name","component":{"Text":{"text":{"path":"/channelName"},"usageHint":"h3"}}},{"id":"divider","component":{"Divider":{}}},{"id":"messages","component":{"Column":{"children":{"explicitList":["message1","message2"]},"gap":"medium"}}},{"id":"message1","component":{"Row":{"children":{"explicitList":["avatar1","msg1-content"]},"gap":"small","alignment":"start"}}},{"id":"avatar1","component":{"Image":{"url":{"path":"/msg1Avatar"},"fit":"cover","usageHint":"avatar"}}},{"id":"msg1-content","component":{"Column":{"children":{"explicitList":["msg1-header","msg1-text"]},"gap":"small"}}},{"id":"msg1-header","component":{"Row":{"children":{"explicitList":["msg1-username","msg1-time"]},"gap":"small","alignment":"center"}}},{"id":"msg1-username","component":{"Text":{"text":{"path":"/msg1Username"},"usageHint":"h4"}}},{"id":"msg1-time","component":{"Text":{"text":{"path":"/msg1Time"},"usageHint":"caption"}}},{"id":"msg1-text","component":{"Text":{"text":{"path":"/msg1Text"},"usageHint":"body"}}},{"id":"message2","component":{"Row":{"children":{"explicitList":["avatar2","msg2-content"]},"gap":"small","alignment":"start"}}},{"id":"avatar2","component":{"Image":{"url":{"path":"/msg2Avatar"},"fit":"cover","usageHint":"avatar"}}},{"id":"msg2-content","component":{"Column":{"children":{"explicitList":["msg2-header","msg2-text"]},"gap":"small"}}},{"id":"msg2-header","component":{"Row":{"children":{"explicitList":["msg2-username","msg2-time"]},"gap":"small","alignment":"center"}}},{"id":"msg2-username","component":{"Text":{"text":{"path":"/msg2Username"},"usageHint":"h4"}}},{"id":"msg2-time","component":{"Text":{"text":{"path":"/msg2Time"},"usageHint":"caption"}}},{"id":"msg2-text","component":{"Text":{"text":{"path":"/msg2Text"},"usageHint":"body"}}}]}}|,
      ~S|{"dataModelUpdate":{"surfaceId":"gallery-chat","contents":[{"key":"channelName","valueString":"project-updates"},{"key":"msg1Avatar","valueString":"https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=40&h=40&fit=crop"},{"key":"msg1Username","valueString":"Mike Chen"},{"key":"msg1Time","valueString":"10:32 AM"},{"key":"msg1Text","valueString":"Just pushed the new API changes. Ready for review."},{"key":"msg2Avatar","valueString":"https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=40&h=40&fit=crop"},{"key":"msg2Username","valueString":"Sarah Kim"},{"key":"msg2Time","valueString":"10:45 AM"},{"key":"msg2Text","valueString":"Great! I'll take a look after standup."}]}}|,
      ~s({"beginRendering":{"surfaceId":"gallery-chat","root":"root"}})
    ]
  end

  defp gallery_credit_card do
    [
      ~S|{"surfaceUpdate":{"surfaceId":"gallery-creditcard","components":[{"id":"root","component":{"Card":{"child":"main-column"}}},{"id":"main-column","component":{"Column":{"children":{"explicitList":["card-type-row","card-number","card-details"]},"gap":"large"}}},{"id":"card-type-row","component":{"Row":{"children":{"explicitList":["card-icon","card-type"]},"distribution":"spaceBetween","alignment":"center"}}},{"id":"card-icon","component":{"Icon":{"name":{"literalString":"payment"}}}},{"id":"card-type","component":{"Text":{"text":{"path":"/cardType"},"usageHint":"h4"}}},{"id":"card-number","component":{"Text":{"text":{"path":"/cardNumber"},"usageHint":"h2"}}},{"id":"card-details","component":{"Row":{"children":{"explicitList":["holder-col","expiry-col"]},"distribution":"spaceBetween"}}},{"id":"holder-col","component":{"Column":{"children":{"explicitList":["holder-label","holder-name"]}}}},{"id":"holder-label","component":{"Text":{"text":{"literalString":"CARD HOLDER"},"usageHint":"caption"}}},{"id":"holder-name","component":{"Text":{"text":{"path":"/holderName"},"usageHint":"body"}}},{"id":"expiry-col","component":{"Column":{"children":{"explicitList":["expiry-label","expiry-date"]},"alignment":"end"}}},{"id":"expiry-label","component":{"Text":{"text":{"literalString":"EXPIRES"},"usageHint":"caption"}}},{"id":"expiry-date","component":{"Text":{"text":{"path":"/expiryDate"},"usageHint":"body"}}}]}}|,
      ~S|{"dataModelUpdate":{"surfaceId":"gallery-creditcard","contents":[{"key":"cardType","valueString":"VISA"},{"key":"cardNumber","valueString":"•••• •••• •••• 4242"},{"key":"holderName","valueString":"SARAH JOHNSON"},{"key":"expiryDate","valueString":"09/27"}]}}|,
      ~s({"beginRendering":{"surfaceId":"gallery-creditcard","root":"root"}})
    ]
  end

  defp gallery_coffee_order do
    [
      ~S|{"surfaceUpdate":{"surfaceId":"gallery-coffee","components":[{"id":"root","component":{"Card":{"child":"main-column"}}},{"id":"main-column","component":{"Column":{"children":{"explicitList":["header","items","divider","totals","actions"]},"gap":"medium"}}},{"id":"header","component":{"Row":{"children":{"explicitList":["coffee-icon","store-name"]},"gap":"small","alignment":"center"}}},{"id":"coffee-icon","component":{"Icon":{"name":{"literalString":"shoppingCart"}}}},{"id":"store-name","component":{"Text":{"text":{"path":"/storeName"},"usageHint":"h3"}}},{"id":"items","component":{"Column":{"children":{"explicitList":["item1","item2"]},"gap":"small"}}},{"id":"item1","component":{"Row":{"children":{"explicitList":["item1-details","item1-price"]},"distribution":"spaceBetween","alignment":"start"}}},{"id":"item1-details","component":{"Column":{"children":{"explicitList":["item1-name","item1-size"]}}}},{"id":"item1-name","component":{"Text":{"text":{"path":"/item1Name"},"usageHint":"body"}}},{"id":"item1-size","component":{"Text":{"text":{"path":"/item1Size"},"usageHint":"caption"}}},{"id":"item1-price","component":{"Text":{"text":{"path":"/item1Price"},"usageHint":"body"}}},{"id":"item2","component":{"Row":{"children":{"explicitList":["item2-details","item2-price"]},"distribution":"spaceBetween","alignment":"start"}}},{"id":"item2-details","component":{"Column":{"children":{"explicitList":["item2-name","item2-size"]}}}},{"id":"item2-name","component":{"Text":{"text":{"path":"/item2Name"},"usageHint":"body"}}},{"id":"item2-size","component":{"Text":{"text":{"path":"/item2Size"},"usageHint":"caption"}}},{"id":"item2-price","component":{"Text":{"text":{"path":"/item2Price"},"usageHint":"body"}}},{"id":"divider","component":{"Divider":{}}},{"id":"totals","component":{"Column":{"children":{"explicitList":["subtotal-row","tax-row","total-row"]},"gap":"small"}}},{"id":"subtotal-row","component":{"Row":{"children":{"explicitList":["subtotal-label","subtotal-value"]},"distribution":"spaceBetween"}}},{"id":"subtotal-label","component":{"Text":{"text":{"literalString":"Subtotal"},"usageHint":"caption"}}},{"id":"subtotal-value","component":{"Text":{"text":{"path":"/subtotal"},"usageHint":"body"}}},{"id":"tax-row","component":{"Row":{"children":{"explicitList":["tax-label","tax-value"]},"distribution":"spaceBetween"}}},{"id":"tax-label","component":{"Text":{"text":{"literalString":"Tax"},"usageHint":"caption"}}},{"id":"tax-value","component":{"Text":{"text":{"path":"/tax"},"usageHint":"body"}}},{"id":"total-row","component":{"Row":{"children":{"explicitList":["total-label","total-value"]},"distribution":"spaceBetween"}}},{"id":"total-label","component":{"Text":{"text":{"literalString":"Total"},"usageHint":"h4"}}},{"id":"total-value","component":{"Text":{"text":{"path":"/total"},"usageHint":"h3"}}},{"id":"actions","component":{"Row":{"children":{"explicitList":["purchase-btn","cart-btn"]},"gap":"small"}}},{"id":"purchase-btn-text","component":{"Text":{"text":{"literalString":"Purchase"}}}},{"id":"purchase-btn","component":{"Button":{"child":"purchase-btn-text","action":"purchase","primary":true}}},{"id":"cart-btn-text","component":{"Text":{"text":{"literalString":"Add to cart"}}}},{"id":"cart-btn","component":{"Button":{"child":"cart-btn-text","action":"add_cart"}}}]}}|,
      ~S|{"dataModelUpdate":{"surfaceId":"gallery-coffee","contents":[{"key":"storeName","valueString":"Sunrise Coffee"},{"key":"item1Name","valueString":"Oat Milk Latte"},{"key":"item1Size","valueString":"Grande, Extra Shot"},{"key":"item1Price","valueString":"$6.45"},{"key":"item2Name","valueString":"Chocolate Croissant"},{"key":"item2Size","valueString":"Warmed"},{"key":"item2Price","valueString":"$4.25"},{"key":"subtotal","valueString":"$10.70"},{"key":"tax","valueString":"$0.96"},{"key":"total","valueString":"$11.66"}]}}|,
      ~s({"beginRendering":{"surfaceId":"gallery-coffee","root":"root"}})
    ]
  end

  defp gallery_restaurant_card do
    [
      ~S|{"surfaceUpdate":{"surfaceId":"gallery-restaurant","components":[{"id":"root","component":{"Card":{"child":"main-column"}}},{"id":"main-column","component":{"Column":{"children":{"explicitList":["restaurant-image","content"]},"gap":"small"}}},{"id":"restaurant-image","component":{"Image":{"url":{"path":"/image"},"fit":"cover"}}},{"id":"content","component":{"Column":{"children":{"explicitList":["name-row","cuisine","rating-row","details-row"]},"gap":"small"}}},{"id":"name-row","component":{"Row":{"children":{"explicitList":["restaurant-name","price-range"]},"distribution":"spaceBetween","alignment":"center"}}},{"id":"restaurant-name","component":{"Text":{"text":{"path":"/name"},"usageHint":"h3"}}},{"id":"price-range","component":{"Text":{"text":{"path":"/priceRange"},"usageHint":"body"}}},{"id":"cuisine","component":{"Text":{"text":{"path":"/cuisine"},"usageHint":"caption"}}},{"id":"rating-row","component":{"Row":{"children":{"explicitList":["star-icon","rating","reviews"]},"gap":"small","alignment":"center"}}},{"id":"star-icon","component":{"Icon":{"name":{"literalString":"star"}}}},{"id":"rating","component":{"Text":{"text":{"path":"/rating"},"usageHint":"body"}}},{"id":"reviews","component":{"Text":{"text":{"path":"/reviewCount"},"usageHint":"caption"}}},{"id":"details-row","component":{"Row":{"children":{"explicitList":["distance","delivery-time"]},"gap":"medium"}}},{"id":"distance","component":{"Text":{"text":{"path":"/distance"},"usageHint":"caption"}}},{"id":"delivery-time","component":{"Text":{"text":{"path":"/deliveryTime"},"usageHint":"caption"}}}]}}|,
      ~S|{"dataModelUpdate":{"surfaceId":"gallery-restaurant","contents":[{"key":"image","valueString":"https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=400&h=200&fit=crop"},{"key":"name","valueString":"The Italian Kitchen"},{"key":"priceRange","valueString":"$$$"},{"key":"cuisine","valueString":"Italian • Pasta • Wine Bar"},{"key":"rating","valueString":"4.8"},{"key":"reviewCount","valueString":"(2,847 reviews)"},{"key":"distance","valueString":"0.8 mi"},{"key":"deliveryTime","valueString":"25-35 min"}]}}|,
      ~s({"beginRendering":{"surfaceId":"gallery-restaurant","root":"root"}})
    ]
  end

  defp gallery_email_compose do
    [
      ~S|{"surfaceUpdate":{"surfaceId":"gallery-email","components":[{"id":"root","component":{"Card":{"child":"main-column"}}},{"id":"main-column","component":{"Column":{"children":{"explicitList":["from-row","to-row","subject-row","divider","message","actions"]},"gap":"small"}}},{"id":"from-row","component":{"Row":{"children":{"explicitList":["from-label","from-value"]},"gap":"medium","alignment":"center"}}},{"id":"from-label","component":{"Text":{"text":{"literalString":"FROM"},"usageHint":"caption"}}},{"id":"from-value","component":{"Text":{"text":{"path":"/from"},"usageHint":"body"}}},{"id":"to-row","component":{"Row":{"children":{"explicitList":["to-label","to-value"]},"gap":"medium","alignment":"center"}}},{"id":"to-label","component":{"Text":{"text":{"literalString":"TO"},"usageHint":"caption"}}},{"id":"to-value","component":{"Text":{"text":{"path":"/to"},"usageHint":"body"}}},{"id":"subject-row","component":{"Row":{"children":{"explicitList":["subject-label","subject-value"]},"gap":"medium","alignment":"center"}}},{"id":"subject-label","component":{"Text":{"text":{"literalString":"SUBJECT"},"usageHint":"caption"}}},{"id":"subject-value","component":{"Text":{"text":{"path":"/subject"},"usageHint":"body"}}},{"id":"divider","component":{"Divider":{}}},{"id":"message","component":{"Column":{"children":{"explicitList":["greeting","body","closing","signature"]},"gap":"medium"}}},{"id":"greeting","component":{"Text":{"text":{"path":"/greeting"},"usageHint":"body"}}},{"id":"body","component":{"Text":{"text":{"path":"/body"},"usageHint":"body"}}},{"id":"closing","component":{"Text":{"text":{"path":"/closing"},"usageHint":"body"}}},{"id":"signature","component":{"Text":{"text":{"path":"/signature"},"usageHint":"body"}}},{"id":"actions","component":{"Row":{"children":{"explicitList":["send-btn","discard-btn"]},"gap":"small"}}},{"id":"send-btn-text","component":{"Text":{"text":{"literalString":"Send email"}}}},{"id":"send-btn","component":{"Button":{"child":"send-btn-text","action":"send","primary":true}}},{"id":"discard-btn-text","component":{"Text":{"text":{"literalString":"Discard"}}}},{"id":"discard-btn","component":{"Button":{"child":"discard-btn-text","action":"discard"}}}]}}|,
      ~S|{"dataModelUpdate":{"surfaceId":"gallery-email","contents":[{"key":"from","valueString":"alex@acme.com"},{"key":"to","valueString":"jordan@acme.com"},{"key":"subject","valueString":"Q4 Revenue Forecast"},{"key":"greeting","valueString":"Hi Jordan,"},{"key":"body","valueString":"Following up on our call. Please review the attached Q4 forecast and let me know if you have questions before the board meeting."},{"key":"closing","valueString":"Best,"},{"key":"signature","valueString":"Alex"}]}}|,
      ~s({"beginRendering":{"surfaceId":"gallery-email","root":"root"}})
    ]
  end

  defp gallery_sports_player do
    [
      ~S|{"surfaceUpdate":{"surfaceId":"gallery-player","components":[{"id":"root","component":{"Card":{"child":"main-column"}}},{"id":"main-column","component":{"Column":{"children":{"explicitList":["player-image","player-info","divider","stats-row"]},"gap":"medium","alignment":"center"}}},{"id":"player-image","component":{"Image":{"url":{"path":"/playerImage"},"fit":"cover"}}},{"id":"player-info","component":{"Column":{"children":{"explicitList":["player-name","player-details"]},"alignment":"center"}}},{"id":"player-name","component":{"Text":{"text":{"path":"/playerName"},"usageHint":"h2"}}},{"id":"player-details","component":{"Row":{"children":{"explicitList":["player-number","player-team"]},"gap":"small","alignment":"center"}}},{"id":"player-number","component":{"Text":{"text":{"path":"/number"},"usageHint":"h3"}}},{"id":"player-team","component":{"Text":{"text":{"path":"/team"},"usageHint":"caption"}}},{"id":"divider","component":{"Divider":{}}},{"id":"stats-row","component":{"Row":{"children":{"explicitList":["stat1-col","stat2-col","stat3-col"]},"distribution":"spaceAround"}}},{"id":"stat1-col","component":{"Column":{"children":{"explicitList":["stat1-value","stat1-label"]},"alignment":"center"}}},{"id":"stat1-value","component":{"Text":{"text":{"path":"/stat1Value"},"usageHint":"h3"}}},{"id":"stat1-label","component":{"Text":{"text":{"path":"/stat1Label"},"usageHint":"caption"}}},{"id":"stat2-col","component":{"Column":{"children":{"explicitList":["stat2-value","stat2-label"]},"alignment":"center"}}},{"id":"stat2-value","component":{"Text":{"text":{"path":"/stat2Value"},"usageHint":"h3"}}},{"id":"stat2-label","component":{"Text":{"text":{"path":"/stat2Label"},"usageHint":"caption"}}},{"id":"stat3-col","component":{"Column":{"children":{"explicitList":["stat3-value","stat3-label"]},"alignment":"center"}}},{"id":"stat3-value","component":{"Text":{"text":{"path":"/stat3Value"},"usageHint":"h3"}}},{"id":"stat3-label","component":{"Text":{"text":{"path":"/stat3Label"},"usageHint":"caption"}}}]}}|,
      ~S|{"dataModelUpdate":{"surfaceId":"gallery-player","contents":[{"key":"playerImage","valueString":"https://images.unsplash.com/photo-1546519638-68e109498ffc?w=200&h=200&fit=crop"},{"key":"playerName","valueString":"Marcus Johnson"},{"key":"number","valueString":"#23"},{"key":"team","valueString":"LA Lakers"},{"key":"stat1Value","valueString":"28.4"},{"key":"stat1Label","valueString":"PPG"},{"key":"stat2Value","valueString":"7.2"},{"key":"stat2Label","valueString":"RPG"},{"key":"stat3Value","valueString":"6.8"},{"key":"stat3Label","valueString":"APG"}]}}|,
      ~s({"beginRendering":{"surfaceId":"gallery-player","root":"root"}})
    ]
  end

  defp gallery_recipe_card do
    [
      ~S|{"surfaceUpdate":{"surfaceId":"gallery-recipe","components":[{"id":"root","component":{"Card":{"child":"main-column"}}},{"id":"main-column","component":{"Column":{"children":{"explicitList":["recipe-image","content"]},"gap":"small"}}},{"id":"recipe-image","component":{"Image":{"url":{"path":"/image"},"fit":"cover"}}},{"id":"content","component":{"Column":{"children":{"explicitList":["title","rating-row","times-row","servings"]},"gap":"small"}}},{"id":"title","component":{"Text":{"text":{"path":"/title"},"usageHint":"h3"}}},{"id":"rating-row","component":{"Row":{"children":{"explicitList":["star-icon","rating","review-count"]},"gap":"small","alignment":"center"}}},{"id":"star-icon","component":{"Icon":{"name":{"literalString":"star"}}}},{"id":"rating","component":{"Text":{"text":{"path":"/rating"},"usageHint":"body"}}},{"id":"review-count","component":{"Text":{"text":{"path":"/reviewCount"},"usageHint":"caption"}}},{"id":"times-row","component":{"Row":{"children":{"explicitList":["prep-time","cook-time"]},"gap":"medium"}}},{"id":"prep-time","component":{"Row":{"children":{"explicitList":["prep-icon","prep-text"]},"gap":"small","alignment":"center"}}},{"id":"prep-icon","component":{"Icon":{"name":{"literalString":"clock"}}}},{"id":"prep-text","component":{"Text":{"text":{"path":"/prepTime"},"usageHint":"caption"}}},{"id":"cook-time","component":{"Row":{"children":{"explicitList":["cook-icon","cook-text"]},"gap":"small","alignment":"center"}}},{"id":"cook-icon","component":{"Icon":{"name":{"literalString":"clock"}}}},{"id":"cook-text","component":{"Text":{"text":{"path":"/cookTime"},"usageHint":"caption"}}},{"id":"servings","component":{"Text":{"text":{"path":"/servings"},"usageHint":"caption"}}}]}}|,
      ~S|{"dataModelUpdate":{"surfaceId":"gallery-recipe","contents":[{"key":"image","valueString":"https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=400&h=200&fit=crop"},{"key":"title","valueString":"Mediterranean Quinoa Bowl"},{"key":"rating","valueString":"4.9"},{"key":"reviewCount","valueString":"(1,247 reviews)"},{"key":"prepTime","valueString":"15 min prep"},{"key":"cookTime","valueString":"20 min cook"},{"key":"servings","valueString":"Serves 4"}]}}|,
      ~s({"beginRendering":{"surfaceId":"gallery-recipe","root":"root"}})
    ]
  end

  defp gallery_music_player do
    [
      ~S|{"surfaceUpdate":{"surfaceId":"gallery-music","components":[{"id":"root","component":{"Card":{"child":"main-column"}}},{"id":"main-column","component":{"Column":{"children":{"explicitList":["album-art","track-info","time-row","controls"]},"gap":"small","alignment":"center"}}},{"id":"album-art","component":{"Image":{"url":{"path":"/albumArt"},"fit":"cover"}}},{"id":"track-info","component":{"Column":{"children":{"explicitList":["song-title","artist"]},"alignment":"center"}}},{"id":"song-title","component":{"Text":{"text":{"path":"/title"},"usageHint":"h3"}}},{"id":"artist","component":{"Text":{"text":{"path":"/artist"},"usageHint":"caption"}}},{"id":"time-row","component":{"Row":{"children":{"explicitList":["current-time","total-time"]},"distribution":"spaceBetween"}}},{"id":"current-time","component":{"Text":{"text":{"path":"/currentTime"},"usageHint":"caption"}}},{"id":"total-time","component":{"Text":{"text":{"path":"/totalTime"},"usageHint":"caption"}}},{"id":"controls","component":{"Row":{"children":{"explicitList":["prev-btn","play-btn","next-btn"]},"distribution":"center","gap":"medium"}}},{"id":"prev-btn-text","component":{"Icon":{"name":{"literalString":"arrowBack"}}}},{"id":"prev-btn","component":{"Button":{"child":"prev-btn-text","action":"prev"}}},{"id":"play-btn-text","component":{"Text":{"text":{"path":"/playIcon"}}}},{"id":"play-btn","component":{"Button":{"child":"play-btn-text","action":"play","primary":true}}},{"id":"next-btn-text","component":{"Icon":{"name":{"literalString":"arrowForward"}}}},{"id":"next-btn","component":{"Button":{"child":"next-btn-text","action":"next"}}}]}}|,
      ~S|{"dataModelUpdate":{"surfaceId":"gallery-music","contents":[{"key":"albumArt","valueString":"https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=300&h=300&fit=crop"},{"key":"title","valueString":"Blinding Lights"},{"key":"artist","valueString":"The Weeknd"},{"key":"currentTime","valueString":"1:48"},{"key":"totalTime","valueString":"4:22"},{"key":"playIcon","valueString":"⏸"}]}}|,
      ~s({"beginRendering":{"surfaceId":"gallery-music","root":"root"}})
    ]
  end

  defp gallery_workout_summary do
    [
      ~S|{"surfaceUpdate":{"surfaceId":"gallery-workout","components":[{"id":"root","component":{"Card":{"child":"main-column"}}},{"id":"main-column","component":{"Column":{"children":{"explicitList":["header","divider","metrics-row","date"]},"gap":"medium"}}},{"id":"header","component":{"Row":{"children":{"explicitList":["workout-icon","title"]},"gap":"small","alignment":"center"}}},{"id":"workout-icon","component":{"Icon":{"name":{"literalString":"person"}}}},{"id":"title","component":{"Text":{"text":{"literalString":"Workout Complete"},"usageHint":"h3"}}},{"id":"divider","component":{"Divider":{}}},{"id":"metrics-row","component":{"Row":{"children":{"explicitList":["duration-col","calories-col","distance-col"]},"distribution":"spaceAround"}}},{"id":"duration-col","component":{"Column":{"children":{"explicitList":["duration-value","duration-label"]},"alignment":"center"}}},{"id":"duration-value","component":{"Text":{"text":{"path":"/duration"},"usageHint":"h3"}}},{"id":"duration-label","component":{"Text":{"text":{"literalString":"Duration"},"usageHint":"caption"}}},{"id":"calories-col","component":{"Column":{"children":{"explicitList":["calories-value","calories-label"]},"alignment":"center"}}},{"id":"calories-value","component":{"Text":{"text":{"path":"/calories"},"usageHint":"h3"}}},{"id":"calories-label","component":{"Text":{"text":{"literalString":"Calories"},"usageHint":"caption"}}},{"id":"distance-col","component":{"Column":{"children":{"explicitList":["distance-value","distance-label"]},"alignment":"center"}}},{"id":"distance-value","component":{"Text":{"text":{"path":"/distance"},"usageHint":"h3"}}},{"id":"distance-label","component":{"Text":{"text":{"literalString":"Distance"},"usageHint":"caption"}}},{"id":"date","component":{"Text":{"text":{"path":"/date"},"usageHint":"caption"}}}]}}|,
      ~S|{"dataModelUpdate":{"surfaceId":"gallery-workout","contents":[{"key":"duration","valueString":"32:15"},{"key":"calories","valueString":"385"},{"key":"distance","valueString":"5.2 km"},{"key":"date","valueString":"Today at 7:30 AM"}]}}|,
      ~s({"beginRendering":{"surfaceId":"gallery-workout","root":"root"}})
    ]
  end

  defp gallery_event_detail do
    [
      ~S|{"surfaceUpdate":{"surfaceId":"gallery-event","components":[{"id":"root","component":{"Card":{"child":"main-column"}}},{"id":"main-column","component":{"Column":{"children":{"explicitList":["title","time-row","location-row","description","divider","actions"]},"gap":"medium"}}},{"id":"title","component":{"Text":{"text":{"path":"/title"},"usageHint":"h2"}}},{"id":"time-row","component":{"Row":{"children":{"explicitList":["time-icon","time-text"]},"gap":"small","alignment":"center"}}},{"id":"time-icon","component":{"Icon":{"name":{"literalString":"clock"}}}},{"id":"time-text","component":{"Text":{"text":{"path":"/dateTime"},"usageHint":"body"}}},{"id":"location-row","component":{"Row":{"children":{"explicitList":["location-icon","location-text"]},"gap":"small","alignment":"center"}}},{"id":"location-icon","component":{"Icon":{"name":{"literalString":"locationOn"}}}},{"id":"location-text","component":{"Text":{"text":{"path":"/location"},"usageHint":"body"}}},{"id":"description","component":{"Text":{"text":{"path":"/description"},"usageHint":"body"}}},{"id":"divider","component":{"Divider":{}}},{"id":"actions","component":{"Row":{"children":{"explicitList":["accept-btn","decline-btn"]},"gap":"small"}}},{"id":"accept-btn-text","component":{"Text":{"text":{"literalString":"Accept"}}}},{"id":"accept-btn","component":{"Button":{"child":"accept-btn-text","action":"accept","primary":true}}},{"id":"decline-btn-text","component":{"Text":{"text":{"literalString":"Decline"}}}},{"id":"decline-btn","component":{"Button":{"child":"decline-btn-text","action":"decline"}}}]}}|,
      ~S|{"dataModelUpdate":{"surfaceId":"gallery-event","contents":[{"key":"title","valueString":"Product Launch Meeting"},{"key":"dateTime","valueString":"Thu, Dec 19 • 2:00 PM - 3:30 PM"},{"key":"location","valueString":"Conference Room A, Building 2"},{"key":"description","valueString":"Review final product specs and marketing materials before the Q1 launch."}]}}|,
      ~s({"beginRendering":{"surfaceId":"gallery-event","root":"root"}})
    ]
  end

  defp gallery_track_list do
    [
      ~S|{"surfaceUpdate":{"surfaceId":"gallery-tracklist","components":[{"id":"root","component":{"Card":{"child":"main-column"}}},{"id":"main-column","component":{"Column":{"children":{"explicitList":["header","divider","tracks"]},"gap":"small"}}},{"id":"header","component":{"Row":{"children":{"explicitList":["playlist-icon","playlist-name"]},"gap":"small","alignment":"center"}}},{"id":"playlist-icon","component":{"Icon":{"name":{"literalString":"menu"}}}},{"id":"playlist-name","component":{"Text":{"text":{"path":"/playlistName"},"usageHint":"h3"}}},{"id":"divider","component":{"Divider":{}}},{"id":"tracks","component":{"Column":{"children":{"explicitList":["track1","track2","track3"]},"gap":"small"}}},{"id":"track1","component":{"Row":{"children":{"explicitList":["track1-num","track1-art","track1-info","track1-duration"]},"gap":"small","alignment":"center"}}},{"id":"track1-num","component":{"Text":{"text":{"literalString":"1"},"usageHint":"caption"}}},{"id":"track1-art","component":{"Image":{"url":{"path":"/track1Art"},"fit":"cover","usageHint":"icon"}}},{"id":"track1-info","component":{"Column":{"children":{"explicitList":["track1-title","track1-artist"]}}}},{"id":"track1-title","component":{"Text":{"text":{"path":"/track1Title"},"usageHint":"body"}}},{"id":"track1-artist","component":{"Text":{"text":{"path":"/track1Artist"},"usageHint":"caption"}}},{"id":"track1-duration","component":{"Text":{"text":{"path":"/track1Duration"},"usageHint":"caption"}}},{"id":"track2","component":{"Row":{"children":{"explicitList":["track2-num","track2-art","track2-info","track2-duration"]},"gap":"small","alignment":"center"}}},{"id":"track2-num","component":{"Text":{"text":{"literalString":"2"},"usageHint":"caption"}}},{"id":"track2-art","component":{"Image":{"url":{"path":"/track2Art"},"fit":"cover","usageHint":"icon"}}},{"id":"track2-info","component":{"Column":{"children":{"explicitList":["track2-title","track2-artist"]}}}},{"id":"track2-title","component":{"Text":{"text":{"path":"/track2Title"},"usageHint":"body"}}},{"id":"track2-artist","component":{"Text":{"text":{"path":"/track2Artist"},"usageHint":"caption"}}},{"id":"track2-duration","component":{"Text":{"text":{"path":"/track2Duration"},"usageHint":"caption"}}},{"id":"track3","component":{"Row":{"children":{"explicitList":["track3-num","track3-art","track3-info","track3-duration"]},"gap":"small","alignment":"center"}}},{"id":"track3-num","component":{"Text":{"text":{"literalString":"3"},"usageHint":"caption"}}},{"id":"track3-art","component":{"Image":{"url":{"path":"/track3Art"},"fit":"cover","usageHint":"icon"}}},{"id":"track3-info","component":{"Column":{"children":{"explicitList":["track3-title","track3-artist"]}}}},{"id":"track3-title","component":{"Text":{"text":{"path":"/track3Title"},"usageHint":"body"}}},{"id":"track3-artist","component":{"Text":{"text":{"path":"/track3Artist"},"usageHint":"caption"}}},{"id":"track3-duration","component":{"Text":{"text":{"path":"/track3Duration"},"usageHint":"caption"}}}]}}|,
      ~S|{"dataModelUpdate":{"surfaceId":"gallery-tracklist","contents":[{"key":"playlistName","valueString":"Focus Flow"},{"key":"track1Art","valueString":"https://images.unsplash.com/photo-1446057032654-9d8885db76c6?w=50&h=50&fit=crop"},{"key":"track1Title","valueString":"Weightless"},{"key":"track1Artist","valueString":"Marconi Union"},{"key":"track1Duration","valueString":"8:09"},{"key":"track2Art","valueString":"https://images.unsplash.com/photo-1507838153414-b4b713384a76?w=50&h=50&fit=crop"},{"key":"track2Title","valueString":"Clair de Lune"},{"key":"track2Artist","valueString":"Debussy"},{"key":"track2Duration","valueString":"5:12"},{"key":"track3Art","valueString":"https://images.unsplash.com/photo-1459749411175-04bf5292ceea?w=50&h=50&fit=crop"},{"key":"track3Title","valueString":"Ambient Light"},{"key":"track3Artist","valueString":"Brian Eno"},{"key":"track3Duration","valueString":"6:45"}]}}|,
      ~s({"beginRendering":{"surfaceId":"gallery-tracklist","root":"root"}})
    ]
  end
end
