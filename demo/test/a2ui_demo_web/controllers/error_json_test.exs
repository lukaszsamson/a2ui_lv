defmodule A2UIDemoWeb.ErrorJSONTest do
  use A2UIDemoWeb.ConnCase, async: true

  test "renders 404" do
    assert A2UIDemoWeb.ErrorJSON.render("404.json", %{}) == %{errors: %{detail: "Not Found"}}
  end

  test "renders 500" do
    assert A2UIDemoWeb.ErrorJSON.render("500.json", %{}) ==
             %{errors: %{detail: "Internal Server Error"}}
  end
end
