defmodule ElDiezWorldCupWeb.PageController do
  use ElDiezWorldCupWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
