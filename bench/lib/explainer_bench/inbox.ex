defmodule ExplainerBench.Inbox do
  @moduledoc """
  The one copy of the truth both pages read: twenty messages in a public
  ETS table. `toggle_read/1` flips a message so the unread count keeps
  moving no matter how many clicks a run makes, and announces the change.
  """
  use GenServer

  @table __MODULE__
  @topic "inbox"
  @size 20

  def start_link(_), do: GenServer.start_link(__MODULE__, nil, name: __MODULE__)

  def size, do: @size
  def topic, do: @topic

  def subscribe, do: Phoenix.PubSub.subscribe(ExplainerBench.PubSub, @topic)

  def list do
    @table |> :ets.tab2list() |> Enum.map(&elem(&1, 1)) |> Enum.sort_by(& &1.id)
  end

  def unread_count, do: Enum.count(list(), &(!&1.read))

  def toggle_read(id) when is_integer(id) and id in 1..@size do
    [{^id, message}] = :ets.lookup(@table, id)
    message = %{message | read: !message.read}
    :ets.insert(@table, {id, message})
    Phoenix.PubSub.broadcast(ExplainerBench.PubSub, @topic, {:inbox_changed, message})
    message
  end

  @impl true
  def init(nil) do
    :ets.new(@table, [:named_table, :public, read_concurrency: true])

    for id <- 1..@size do
      :ets.insert(
        @table,
        {id, %{id: id, from: "Sender #{id}", subject: subject(id), read: rem(id, 3) == 0}}
      )
    end

    {:ok, nil}
  end

  defp subject(id), do: "Message #{id}: a subject line long enough to look like real mail"
end
