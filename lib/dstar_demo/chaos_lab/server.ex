defmodule DstarDemo.ChaosLab.Server do
  @moduledoc """
  Holds the one shared `DstarDemo.ChaosLab` that every reader of
  `/explained/lab` is looking at, and announces each change on PubSub.
  """
  use Agent

  alias DstarDemo.ChaosLab

  @topic "explainer:chaos_lab"

  def start_link(_opts), do: Agent.start_link(&ChaosLab.new/0, name: __MODULE__)

  def subscribe, do: Phoenix.PubSub.subscribe(DstarDemo.PubSub, @topic)
  def unsubscribe, do: Phoenix.PubSub.unsubscribe(DstarDemo.PubSub, @topic)

  def get, do: Agent.get(__MODULE__, & &1)

  def dispatch(action) when is_binary(action) do
    state =
      Agent.get_and_update(__MODULE__, fn s ->
        next = ChaosLab.apply_action(s, action)
        {next, next}
      end)

    Phoenix.PubSub.broadcast(DstarDemo.PubSub, @topic, :chaos_lab_changed)
    state
  end
end
