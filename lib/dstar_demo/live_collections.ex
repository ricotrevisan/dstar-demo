defmodule DstarDemo.LiveCollections do
  @moduledoc "Database-backed work items and their collection-change notifications."

  import Ecto.Query

  alias DstarDemo.LiveCollections.Item
  alias DstarDemo.Repo

  @topic "live_collections:items"
  @filters ~w(all queued active done)

  def topic, do: @topic

  def subscribe do
    Phoenix.PubSub.subscribe(DstarDemo.PubSub, @topic)
  end

  def normalize_filter(filter) when filter in @filters, do: filter
  def normalize_filter(_filter), do: "all"

  def list_items(filter \\ "all") do
    filter = normalize_filter(filter)

    Item
    |> maybe_filter(filter)
    |> order_by([item], desc: item.id)
    |> Repo.all()
  end

  def list_arrivals do
    Item
    |> order_by([item], asc: item.id)
    |> Repo.all()
  end

  def create_item(attrs) when is_map(attrs) do
    result = %Item{} |> Item.changeset(attrs) |> Repo.insert()
    broadcast_success(result, :created)
  end

  def advance_item(id) when is_binary(id) do
    case Integer.parse(id) do
      {parsed, ""} -> advance_item(parsed)
      _other -> {:error, :invalid_id}
    end
  end

  def advance_item(id) when is_integer(id) and id > 0 do
    result =
      Repo.transaction(fn ->
        item = Repo.one(from(item in Item, where: item.id == ^id, lock: "FOR UPDATE"))
        if is_nil(item), do: Repo.rollback(:not_found)

        item
        |> Item.changeset(%{status: next_status(item.status)})
        |> Repo.update!()
      end)

    case result do
      {:ok, item} -> broadcast_success({:ok, item}, :updated)
      {:error, reason} -> {:error, reason}
    end
  end

  def advance_item(_id), do: {:error, :invalid_id}

  defp maybe_filter(query, "all"), do: query
  defp maybe_filter(query, status), do: where(query, [item], item.status == ^status)

  defp next_status(:queued), do: :active
  defp next_status(:active), do: :done
  defp next_status(:done), do: :queued

  defp broadcast_success({:ok, item} = result, action) do
    Phoenix.PubSub.broadcast(
      DstarDemo.PubSub,
      @topic,
      {:live_collection_changed, action, item}
    )

    result
  end

  defp broadcast_success(error, _action), do: error
end
