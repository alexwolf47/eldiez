defmodule ElDiezWorldCupWeb.AdminSessionHTML do
  @moduledoc "Renders the admin login page."
  use ElDiezWorldCupWeb, :html

  def new(assigns) do
    ~H"""
    <div class="min-h-screen bg-base-200 flex items-center justify-center px-4">
      <div class="card bg-base-100 shadow-xl w-full max-w-sm">
        <div class="card-body gap-4">
          <div class="text-center space-y-1">
            <div class="text-4xl">🔒</div>
            <h1 class="text-2xl font-black">Draw Admin</h1>
            <p class="text-sm text-base-content/60">Enter the password to continue.</p>
          </div>

          <Layouts.flash_group flash={@flash} />

          <.form for={%{}} action={~p"/admin/login"} method="post" class="space-y-3">
            <div class="form-control">
              <label class="label" for="password">
                <span class="label-text">Password</span>
              </label>
              <input
                type="password"
                id="password"
                name="password"
                autocomplete="current-password"
                autofocus
                required
                class="input input-bordered w-full"
                placeholder="••••••••"
              />
            </div>
            <button type="submit" class="btn btn-primary w-full">Log in</button>
          </.form>

          <a href="/" class="link link-hover text-center text-sm text-base-content/60">
            ← Back to the draw
          </a>
        </div>
      </div>
    </div>
    """
  end
end
