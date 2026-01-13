defmodule A2uiLvWeb.PageController do
  use A2uiLvWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
