defmodule DstarDemo.Inbox do
  @moduledoc """
  A tiny shared inbox for the `/explained/dx` demo.

  It stands in for the database: one copy of the truth, shared by every
  reader, changed only through these functions, and announced on PubSub so
  open pages can re-read it. In-memory on purpose — the demo should work
  without Postgres — and capped so a busy demo cannot grow it forever.
  """
  use Agent

  @topic "explainer:inbox"
  @max 8

  @seed [
    {"Zach", "Signals are out — have a look?"},
    {"Ada", "Deploy went out, nobody noticed. Good sign."},
    {"Ben", "Can the sidebar badge update by itself?"},
    {"Dee", "Lunch on Friday?"}
  ]

  @senders ~w(Ada Ben Cy Dee Eve Zach)
  @subjects [
    "Quick question about the router",
    "Re: the sidebar badge",
    "Your stream reconnected",
    "Release notes draft",
    "Is this thing live?",
    "Another tab says hi"
  ]

  def start_link(_opts), do: Agent.start_link(&seed/0, name: __MODULE__)

  def topic, do: @topic
  def subscribe, do: Phoenix.PubSub.subscribe(DstarDemo.PubSub, @topic)
  def unsubscribe, do: Phoenix.PubSub.unsubscribe(DstarDemo.PubSub, @topic)

  @doc "Newest first."
  def list, do: Agent.get(__MODULE__, & &1.messages)

  def unread_count, do: Enum.count(list(), &(!&1.read))

  def mark_read(id) when is_integer(id) do
    update(fn messages ->
      Enum.map(messages, fn m -> if m.id == id, do: %{m | read: true}, else: m end)
    end)
  end

  def mark_all_read, do: update(fn messages -> Enum.map(messages, &%{&1 | read: true}) end)

  def deliver do
    update(fn messages, next_id ->
      message = %{
        id: next_id,
        from: Enum.random(@senders),
        subject: Enum.random(@subjects),
        read: false
      }

      Enum.take([message | messages], @max)
    end)
  end

  def reset do
    Agent.update(__MODULE__, fn _ -> seed() end)
    broadcast()
  end

  defp update(fun) when is_function(fun, 1), do: update(fn messages, _ -> fun.(messages) end)

  defp update(fun) when is_function(fun, 2) do
    Agent.update(__MODULE__, fn state ->
      %{state | messages: fun.(state.messages, state.next_id), next_id: state.next_id + 1}
    end)

    broadcast()
  end

  # A nudge, not a payload: every listener re-reads the truth itself.
  defp broadcast do
    Phoenix.PubSub.broadcast(DstarDemo.PubSub, @topic, :inbox_changed)
    :ok
  end

  defp seed do
    messages =
      @seed
      |> Enum.with_index(1)
      |> Enum.map(fn {{from, subject}, id} ->
        %{id: id, from: from, subject: subject, read: id > 2}
      end)

    %{messages: messages, next_id: length(@seed) + 1}
  end
end
