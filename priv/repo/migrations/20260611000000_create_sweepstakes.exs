defmodule ElDiezWorldCup.Repo.Migrations.CreateSweepstakes do
  use Ecto.Migration

  def change do
    create table(:settings) do
      add :scheduled_at, :utc_datetime
      add :status, :string, null: false, default: "pending"
      add :seed, :integer

      timestamps(type: :utc_datetime)
    end

    create table(:assignments) do
      add :pot, :integer, null: false
      add :position, :integer, null: false
      add :player, :string, null: false
      add :team, :string, null: false
      add :flag, :string
      add :odds, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:assignments, [:pot, :position])
    create unique_index(:assignments, [:pot, :player])
  end
end
