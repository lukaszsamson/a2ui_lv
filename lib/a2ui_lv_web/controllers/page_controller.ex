defmodule A2uiLvWeb.PageController do
  use A2uiLvWeb, :controller

  def home(conn, _params) do
    conn
    |> assign(:current_scope, nil)
    |> render(:home)
  end
end
