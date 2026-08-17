defmodule DstarDemo.LiveCollectionsTest do
  use DstarDemo.DataCase, async: true

  alias DstarDemo.LiveCollections
  alias DstarDemo.LiveCollections.Item
  alias DstarDemo.Repo

  setup do
    :ok = LiveCollections.subscribe()
    on_exit(fn -> Phoenix.PubSub.unsubscribe(DstarDemo.PubSub, LiveCollections.topic()) end)
    :ok
  end

  test "changeset trims and validates persisted fields" do
    assert {:ok, item} = LiveCollections.create_item(%{"title" => "  Trace the nudge  "})
    assert item.title == "Trace the nudge"
    assert item.status == :queued

    assert {:error, changeset} = LiveCollections.create_item(%{"title" => " "})
    assert {:title, {"can't be blank", _}} = List.keyfind(changeset.errors, :title, 0)

    assert {:error, nil_changeset} = LiveCollections.create_item(%{"title" => nil})
    assert Keyword.has_key?(nil_changeset.errors, :title)

    assert {:error, changeset} =
             LiveCollections.create_item(%{"title" => "valid", "status" => "invented"})

    assert Keyword.has_key?(changeset.errors, :status)
  end

  test "lists each tab's filter independently in deterministic order" do
    older = insert_item!("Queued first", :queued)
    active = insert_item!("Active", :active)
    newer = insert_item!("Queued second", :queued)
    done = insert_item!("Done", :done)

    assert Enum.map(LiveCollections.list_items("queued"), & &1.id) == [newer.id, older.id]
    assert Enum.map(LiveCollections.list_items("active"), & &1.id) == [active.id]
    assert Enum.map(LiveCollections.list_items("done"), & &1.id) == [done.id]

    all_ids = Enum.map(LiveCollections.list_items("all"), & &1.id)
    assert all_ids == Enum.sort([older.id, active.id, newer.id, done.id], :desc)
    assert Enum.map(LiveCollections.list_items("untrusted"), & &1.id) == all_ids
    assert LiveCollections.normalize_filter(nil) == "all"
  end

  test "arrivals are oldest first" do
    first = insert_item!("First", :queued)
    second = insert_item!("Second", :done)
    assert Enum.map(LiveCollections.list_arrivals(), & &1.id) == [first.id, second.id]
  end

  test "broadcasts successful commits, never failed changesets" do
    assert {:ok, item} = LiveCollections.create_item(%{"title" => "Broadcast me"})
    assert_receive {:live_collection_changed, :created, ^item}

    assert {:error, _changeset} = LiveCollections.create_item(%{"title" => ""})
    refute_receive {:live_collection_changed, :created, _}
  end

  test "advances under a row lock and broadcasts the committed row" do
    item = insert_item!("Move me", :queued)

    assert {:ok, active} = LiveCollections.advance_item(Integer.to_string(item.id))
    assert active.status == :active
    assert_receive {:live_collection_changed, :updated, ^active}

    assert {:ok, done} = LiveCollections.advance_item(item.id)
    assert done.status == :done
    assert_receive {:live_collection_changed, :updated, ^done}

    assert {:ok, queued} = LiveCollections.advance_item(item.id)
    assert queued.status == :queued
    assert_receive {:live_collection_changed, :updated, ^queued}

    assert {:error, :invalid_id} = LiveCollections.advance_item("1oops")
    assert {:error, :not_found} = LiveCollections.advance_item(item.id + 100_000)
    refute_receive {:live_collection_changed, :updated, _}
  end

  defp insert_item!(title, status) do
    %Item{}
    |> Item.changeset(%{title: title, status: status})
    |> Repo.insert!()
  end
end
