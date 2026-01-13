defmodule A2uiLvWeb.ErrorJSONTest do
  use A2uiLvWeb.ConnCase, async: true

  test "renders 404" do
    assert A2uiLvWeb.ErrorJSON.render("404.json", %{}) == %{errors: %{detail: "Not Found"}}
  end

  test "renders 500" do
    assert A2uiLvWeb.ErrorJSON.render("500.json", %{}) ==
             %{errors: %{detail: "Internal Server Error"}}
  end
end
