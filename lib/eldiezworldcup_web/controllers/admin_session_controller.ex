defmodule ElDiezWorldCupWeb.AdminSessionController do
  @moduledoc "Password-only login for the sweepstakes admin console."
  use ElDiezWorldCupWeb, :controller

  @password "pizza@home"

  def new(conn, _params) do
    render(conn, :new, page_title: "Admin Login")
  end

  def create(conn, %{"password" => password}) do
    if Plug.Crypto.secure_compare(password, @password) do
      conn
      |> put_session(:admin_authed, true)
      |> configure_session(renew: true)
      |> put_flash(:info, "Welcome to the admin console.")
      |> redirect(to: ~p"/admin")
    else
      conn
      |> put_flash(:error, "Incorrect password.")
      |> redirect(to: ~p"/admin/login")
    end
  end

  def delete(conn, _params) do
    conn
    |> configure_session(drop: true)
    |> redirect(to: ~p"/admin/login")
  end
end
