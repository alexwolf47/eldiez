defmodule ElDiezWorldCupWeb.HealthController do
  use ElDiezWorldCupWeb, :controller

  def show(conn, _params) do
    text(conn, "ok")
  end
end
