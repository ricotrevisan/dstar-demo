defmodule DstarDemo.Repo.Migrations.CreateLiveCollectionItems do
  use Ecto.Migration

  def change do
    create table(:live_collection_items) do
      add(:title, :string, null: false)
      add(:status, :string, null: false, default: "queued")

      timestamps(type: :utc_datetime)
    end

    create(
      constraint(:live_collection_items, :live_collection_items_status_check,
        check: "status IN ('queued', 'active', 'done')"
      )
    )

    create(index(:live_collection_items, [:status, :id]))
  end
end
