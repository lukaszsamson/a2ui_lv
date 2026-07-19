defmodule A2UI.ReleasedConformanceTest do
  use ExUnit.Case, async: true

  alias A2UI.{Parser, Session}
  alias A2UI.Transport.Events

  for {directory, wire_version} <- [{"v0_9", "v0.9"}, {"v0_9_1", "v0.9.1"}] do
    @directory directory
    @wire_version wire_version

    test "#{wire_version} matches every bundled official schema case" do
      for file <- Path.wildcard("priv/a2ui/spec/#{@directory}/test/cases/*.json") do
        suite = file |> File.read!() |> Jason.decode!()

        for test_case <- suite["tests"] do
          data = Map.put(test_case["data"], "version", @wire_version)

          actual_valid? =
            case suite["schema"] do
              "server_to_client.json" -> not match?({:error, _}, Parser.parse_map(data))
              "client_to_server.json" -> Events.validate_envelope(data) == :ok
            end

          assert actual_valid? == test_case["valid"],
                 "#{file}: #{test_case["description"]} expected valid=#{test_case["valid"]}"
        end
      end
    end

    test "#{wire_version} applies every official Basic Catalog example" do
      for file <- Path.wildcard("priv/a2ui/spec/#{@directory}/catalogs/basic/examples/*.json") do
        document = file |> File.read!() |> Jason.decode!()
        messages = Enum.map(document["messages"], &Map.put(&1, "version", @wire_version))
        {_session, errors} = Session.apply_envelopes(Session.new(), messages)
        assert errors == [], "#{file} produced: #{inspect(errors)}"
      end
    end
  end

  test "released validation rejects duplicate component IDs at the duplicate path" do
    message = %{
      "version" => "v0.9.1",
      "updateComponents" => %{
        "surfaceId" => "main",
        "components" => [
          %{"id" => "same", "component" => "Text", "text" => "one"},
          %{"id" => "same", "component" => "Text", "text" => "two"}
        ]
      }
    }

    assert {:error, {:validation_failed, "/updateComponents/components/1/id", message}} =
             Parser.parse_map(message)

    assert message =~ "unique"
  end

  test "released surfaces buffer forward references until root arrives" do
    catalog = "https://a2ui.org/specification/v0_9/catalogs/basic/catalog.json"
    session = Session.new()

    {:ok, session} =
      Session.apply_json_line(
        session,
        Jason.encode!(%{
          "version" => "v0.9.1",
          "createSurface" => %{"surfaceId" => "main", "catalogId" => catalog}
        })
      )

    refute session.surfaces["main"].ready?

    {:ok, session} =
      Session.apply_json_line(
        session,
        Jason.encode!(%{
          "version" => "v0.9.1",
          "updateComponents" => %{
            "surfaceId" => "main",
            "components" => [
              %{"id" => "root", "component" => "Card", "child" => "later"}
            ]
          }
        })
      )

    assert session.surfaces["main"].ready?
  end

  test "released parser failures use the standard validation error envelope" do
    json =
      Jason.encode!(%{
        "version" => "v0.9.1",
        "updateComponents" => %{
          "surfaceId" => "main",
          "components" => [%{"id" => "root", "component" => "Text", "text" => 42}]
        }
      })

    assert {:error,
            %{
              "error" => %{
                "code" => "VALIDATION_FAILED",
                "surfaceId" => "main",
                "path" => "/updateComponents/components/0/text"
              }
            }} = Session.apply_json_line(Session.new(), json)
  end

  test "released paths reject malformed escapes and non-absolute model updates" do
    for path <- ["relative/path", "/bad~2escape", "/bad~"] do
      message = %{
        "version" => "v0.9.1",
        "updateDataModel" => %{"surfaceId" => "main", "path" => path, "value" => 1}
      }

      assert {:error, {:validation_failed, "/updateDataModel/path", _}} =
               Parser.parse_map(message)
    end
  end

  test "released updates reject invalid array indices without mutating the model" do
    catalog = "https://a2ui.org/specification/v0_9/catalogs/basic/catalog.json"

    messages = [
      %{
        "version" => "v0.9.1",
        "createSurface" => %{"surfaceId" => "main", "catalogId" => catalog}
      },
      %{
        "version" => "v0.9.1",
        "updateDataModel" => %{"surfaceId" => "main", "value" => %{"items" => ["a"]}}
      }
    ]

    {session, []} = Session.apply_envelopes(Session.new(), messages)

    for path <- ["/items/nope", "/items/01", "/items/-1"] do
      message = %{
        "version" => "v0.9.1",
        "updateDataModel" => %{"surfaceId" => "main", "path" => path, "value" => "bad"}
      }

      assert {:error, %{"error" => %{"code" => "VALIDATION_FAILED"}}} =
               Session.apply_json_line(session, Jason.encode!(message))
    end

    assert session.surfaces["main"].data_model == %{"items" => ["a"]}
  end

  test "official function schemas accept their full declared value domains" do
    required = %{
      "version" => "v0.9.1",
      "updateComponents" => %{
        "surfaceId" => "main",
        "components" => [
          %{
            "id" => "root",
            "component" => "Button",
            "child" => "label",
            "action" => %{
              "functionCall" => %{
                "call" => "required",
                "args" => %{"value" => %{"nested" => true}},
                "returnType" => "boolean"
              }
            }
          }
        ]
      }
    }

    assert {:surface_update, _} = Parser.parse_map(required)
  end
end
