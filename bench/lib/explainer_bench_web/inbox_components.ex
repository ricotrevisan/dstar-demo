defmodule ExplainerBenchWeb.InboxComponents do
  @moduledoc """
  The markup both pages render, so neither model ships more HTML than the
  other. Only the click attribute differs (`phx-click` vs `data-on:click`).
  """
  use Phoenix.Component

  attr :unread, :integer, required: true

  def sidebar(assigns) do
    ~H"""
    <nav id="sidebar"><a href="#messages">Inbox</a> <span class="badge">{@unread}</span></nav>
    """
  end

  attr :id, :string, required: true
  attr :message, :map, required: true
  attr :rest, :global

  def row(assigns) do
    ~H"""
    <article id={@id} class={["row", !@message.read && "unread"]} {@rest}>
      <strong>{@message.subject}</strong>
      <span>{@message.from}</span>
      <button type="button">{if(@message.read, do: "Mark unread", else: "Mark read")}</button>
    </article>
    """
  end
end
