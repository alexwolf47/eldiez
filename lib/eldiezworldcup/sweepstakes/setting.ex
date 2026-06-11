defmodule ElDiezWorldCup.Sweepstakes.Setting do
  @moduledoc """
  Singleton row (id: 1) holding the draw configuration and lifecycle status.

  Statuses:
    * `"pending"`   – no draw scheduled yet
    * `"scheduled"` – a future start time is set
    * `"drawing"`   – the live draw is in progress
    * `"complete"`  – all teams have been drawn
  """
  use Ecto.Schema
  import Ecto.Changeset

  @statuses ~w(pending scheduled drawing complete)

  schema "settings" do
    field :scheduled_at, :utc_datetime
    field :status, :string, default: "pending"
    field :seed, :integer

    timestamps(type: :utc_datetime)
  end

  def statuses, do: @statuses

  def changeset(setting, attrs) do
    setting
    |> cast(attrs, [:scheduled_at, :status, :seed])
    |> validate_inclusion(:status, @statuses)
  end
end
