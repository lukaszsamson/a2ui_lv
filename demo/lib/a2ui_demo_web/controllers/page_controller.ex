defmodule A2UIDemoWeb.PageController do
  use A2UIDemoWeb, :controller

  def home(conn, _params) do
    conn
    |> assign(:current_scope, nil)
    |> render(:home)
  end
end
