defmodule DstarDemo.LiveCollections.Item do
  use Ecto.Schema
  import Ecto.Changeset

  @statuses [:queued, :active, :done]

  schema "live_collection_items" do
    field(:title, :string)
    field(:status, Ecto.Enum, values: @statuses, default: :queued)

    timestamps(type: :utc_datetime)
  end

  def changeset(item, attrs) do
    item
    |> cast(attrs, [:title, :status])
    |> update_change(:title, &trim_title/1)
    |> validate_required([:title, :status])
    |> validate_length(:title, min: 2, max: 80)
    |> check_constraint(:status, name: :live_collection_items_status_check)
  end

  defp trim_title(title) when is_binary(title), do: String.trim(title)
  defp trim_title(title), do: title
end
