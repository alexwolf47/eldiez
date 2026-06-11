defmodule ElDiezWorldCup.Sweepstakes.Assignment do
  @moduledoc "A single drawn result: `player` won `team` from `pot` at `position`."
  use Ecto.Schema
  import Ecto.Changeset

  schema "assignments" do
    field :pot, :integer
    field :position, :integer
    field :player, :string
    field :team, :string
    field :flag, :string
    field :odds, :string

    timestamps(type: :utc_datetime)
  end

  def changeset(assignment, attrs) do
    assignment
    |> cast(attrs, [:pot, :position, :player, :team, :flag, :odds])
    |> validate_required([:pot, :position, :player, :team])
  end
end
