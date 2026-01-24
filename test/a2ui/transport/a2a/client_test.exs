defmodule A2UI.Transport.A2A.ClientTest do
  use ExUnit.Case, async: true

  alias A2UI.Transport.A2A.Client
  alias A2UI.ClientCapabilities

  # Note: Most client tests require a running A2A server.
  # These tests focus on the client's behavior that can be tested in isolation.

  describe "start_link/1" do
    @tag :integration
    test "starts the client process" do
      # This test requires Req to be available
      if A2UI.Transport.A2A.available?() do
        {:ok, pid} =
          Client.start_link(
            base_url: "http://localhost:3002",
            capabilities: ClientCapabilities.default()
          )

        assert Process.alive?(pid)
        GenServer.stop(pid)
      end
    end

    test "requires base_url option" do
      # This will fail to start because base_url is required
      if A2UI.Transport.A2A.available?() do
        # The KeyError is raised in init, so start_link will exit
        Process.flag(:trap_exit, true)

        result = Client.start_link(capabilities: ClientCapabilities.default())

        received_exit =
          receive do
            {:EXIT, _, _} -> true
          after
            100 -> false
          end

        assert match?({:error, _}, result) or received_exit
      end
    end
  end

  describe "A2UI.Transport.A2A module" do
    test "available?/0 returns boolean" do
      result = A2UI.Transport.A2A.available?()
      assert is_boolean(result)
    end

    test "missing_dependency_error/0 returns proper error tuple" do
      {:error, {:missing_dependency, :req, message}} =
        A2UI.Transport.A2A.missing_dependency_error()

      assert is_binary(message)
      assert String.contains?(message, "req")
    end
  end

  describe "behaviors" do
    test "implements UIStream and Events behaviors" do
      # Both behaviors are declared, but may be in separate attribute entries
      all_behaviours =
        Client.__info__(:attributes)
        |> Keyword.get_values(:behaviour)
        |> List.flatten()

      assert A2UI.Transport.UIStream in all_behaviours
      assert A2UI.Transport.Events in all_behaviours
    end
  end
end
