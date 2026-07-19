defmodule A2UI.V0_9_1Test do
  use ExUnit.Case, async: true

  alias A2UI.A2A.DataPart
  alias A2UI.{ClientCapabilities, Event, Functions, Session}

  @catalog "https://a2ui.org/specification/v0_9/catalogs/basic/catalog.json"

  test "parses a released v0.9.1 surface and propagates theme and sync settings" do
    message = %{
      "version" => "v0.9.1",
      "createSurface" => %{
        "surfaceId" => "main",
        "catalogId" => @catalog,
        "sendDataModel" => true,
        "theme" => %{
          "primaryColor" => "#123456",
          "agentDisplayName" => "Planner"
        }
      }
    }

    assert {:begin_rendering, parsed} = A2UI.Parser.parse_map(message)
    assert parsed.protocol_version == :v0_9_1
    assert parsed.send_data_model?
    assert parsed.styles["agentDisplayName"] == "Planner"
  end

  test "v0.9.1 permits surface ID reuse while v0.9 permanently retires it" do
    for {version, atom} <- [{"v0.9", :v0_9}, {"v0.9.1", :v0_9_1}] do
      create = %{
        "version" => version,
        "createSurface" => %{"surfaceId" => "main", "catalogId" => @catalog}
      }

      delete = %{"version" => version, "deleteSurface" => %{"surfaceId" => "main"}}

      {:ok, session} = Session.apply_json_line(Session.new(), Jason.encode!(create))
      {:ok, session} = Session.apply_json_line(session, Jason.encode!(delete))

      if atom == :v0_9_1 do
        assert {:ok, _session} = Session.apply_json_line(session, Jason.encode!(create))
      else
        assert {:error, error} = Session.apply_json_line(session, Jason.encode!(create))
        assert error["error"]["message"] =~ "cannot be reused"
      end
    end
  end

  test "A2A released DataParts use message arrays and continue after per-message errors" do
    messages = [
      %{
        "version" => "v0.9.1",
        "createSurface" => %{"surfaceId" => "main", "catalogId" => @catalog}
      },
      %{
        "version" => "v0.9.1",
        "updateComponents" => %{
          "surfaceId" => "main",
          "components" => [%{"id" => "broken", "component" => "Unknown"}]
        }
      },
      %{
        "version" => "v0.9.1",
        "updateComponents" => %{
          "surfaceId" => "main",
          "components" => [%{"id" => "root", "component" => "Text", "text" => "Ready"}]
        }
      }
    ]

    part = DataPart.wrap_envelopes(messages, :v0_9_1)
    assert part["metadata"]["mimeType"] == "application/a2ui+json"
    assert part["data"] == messages

    extracted = DataPart.extract_envelopes(%{"message" => %{"parts" => [part]}})
    {session, errors} = Session.apply_envelopes(Session.new(), extracted)
    assert length(errors) == 1
    assert session.surfaces["main"].components["root"].props["text"] == "Ready"
  end

  test "released client messages are versioned and advertise versioned capabilities" do
    event =
      Event.build_action(:v0_9_1,
        name: "submit",
        surface_id: "main",
        component_id: "button",
        context: %{}
      )

    assert event["version"] == "v0.9.1"
    message = DataPart.build_client_message(event, ClientCapabilities.default(), :v0_9_1)
    assert get_in(message, ["message", "metadata", "a2uiClientCapabilities", "v0.9.1"])
    assert [^event] = get_in(message, ["message", "parts", Access.at(0), "data"])
  end

  test "capability parsing accepts both published v0.9.1 key variants" do
    for key <- ["v0.9", "v0.9.1"] do
      message = %{
        "message" => %{
          "metadata" => %{
            "a2uiClientCapabilities" => %{
              key => %{"supportedCatalogIds" => [@catalog]}
            }
          }
        }
      }

      assert {:ok, capabilities} = DataPart.parse_client_capabilities(message)
      assert capabilities.supported_catalog_ids == [@catalog]
    end
  end

  test "implements released Basic Catalog formatting, logic, plural and openUrl functions" do
    assert Functions.call("formatNumber", %{"value" => 12_345.6, "decimals" => 2}, %{}, nil) ==
             "12,345.60"

    assert Functions.call("formatCurrency", %{"value" => 12, "currency" => "USD"}, %{}, nil) ==
             "$12.00"

    assert Functions.call(
             "formatDate",
             %{"value" => "2026-07-19T10:11:12Z", "format" => "yyyy-MM-dd HH:mm"},
             %{},
             nil
           ) == "2026-07-19 10:11"

    assert Functions.call(
             "formatDate",
             %{"value" => 1_774_000_000_000, "format" => "yyyy"},
             %{},
             nil
           ) == "2026"

    assert Functions.call(
             "pluralize",
             %{"value" => 2, "two" => "pair", "other" => "many"},
             %{},
             nil
           ) ==
             "many"

    assert Functions.call("and", %{"values" => [true, true]}, %{}, nil) == true

    assert Functions.call("openUrl", %{"url" => "https://example.com"}, %{}, nil) ==
             {:open_url, "https://example.com"}

    assert Functions.call("openUrl", %{"url" => "javascript:alert(1)"}, %{}, nil) == nil

    assert Functions.call(
             "formatString",
             %{"value" => "${formatDate(value:${/date}, format:'yyyy-MM-dd')}"},
             %{"date" => "2026-07-19"},
             nil,
             version: :v0_9_1
           ) == "2026-07-19"
  end

  test "rejects missing versions and unknown Basic Catalog properties with precise paths" do
    assert {:error, :unknown_message_type} =
             A2UI.Parser.parse_map(%{
               "createSurface" => %{"surfaceId" => "main", "catalogId" => @catalog}
             })

    message = %{
      "version" => "v0.9.1",
      "updateComponents" => %{
        "surfaceId" => "main",
        "components" => [
          %{"id" => "root", "component" => "Text", "text" => "Hi", "bogus" => true}
        ]
      }
    }

    assert {:error, {:validation_failed, "/updateComponents/components/0/bogus", _}} =
             A2UI.Parser.parse_map(message)
  end

  test "all bundled official v0.9 and v0.9.1 Basic Catalog examples apply successfully" do
    for version <- ~w(v0_9 v0_9_1),
        file <- Path.wildcard("priv/a2ui/spec/#{version}/catalogs/basic/examples/*.json") do
      document = file |> File.read!() |> Jason.decode!()
      {_session, errors} = Session.apply_envelopes(Session.new(), document["messages"])
      assert errors == [], "#{file} produced: #{inspect(errors)}"
    end
  end
end
