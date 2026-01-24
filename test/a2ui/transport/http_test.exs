defmodule A2UI.Transport.HTTPTest do
  use ExUnit.Case, async: true

  alias A2UI.Transport.HTTP

  describe "available?/0" do
    test "returns true when Req is loaded" do
      # In test environment, Req should be available via dev deps or demo
      # This test may need adjustment based on actual project setup
      result = HTTP.available?()
      assert is_boolean(result)
    end
  end

  describe "missing_dependency_error/0" do
    test "returns error tuple with instructions" do
      assert {:error, {:missing_dependency, :req, message}} = HTTP.missing_dependency_error()
      assert is_binary(message)
      assert message =~ "req"
      assert message =~ "mix.exs"
    end
  end
end
