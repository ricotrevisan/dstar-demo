defmodule DstarDemoWeb.PageHTML do
  @moduledoc """
  This module contains pages rendered by PageController.

  See the `page_html` directory for all templates available.
  """
  use DstarDemoWeb, :html

  embed_templates "page_html/*"

  attr :title, :string, required: true
  attr :status, :string, required: true
  attr :href, :string, required: true
  attr :icon, :string, required: true
  attr :body, :string, required: true

  def demo_tile(assigns) do
    ~H"""
    <a
      href={@href}
      class="block rounded-lg border border-zinc-800 bg-zinc-900 p-4 transition hover:border-zinc-600 hover:bg-zinc-900/80 focus:outline-none focus:ring-2 focus:ring-emerald-300/60"
    >
      <div class="mb-5 flex items-center justify-between gap-3">
        <span class="grid size-9 place-items-center rounded-md bg-zinc-950 text-emerald-300">
          <.icon name={@icon} class="size-5" />
        </span>
        <span class={[
          "rounded-full px-2 py-0.5 text-xs font-medium",
          @status == "ready" && "bg-emerald-300 text-zinc-950",
          @status != "ready" && "bg-zinc-800 text-zinc-300"
        ]}>
          {@status}
        </span>
      </div>
      <h2 class="text-base font-semibold text-zinc-100">{@title}</h2>
      <p class="mt-2 text-sm leading-6 text-zinc-400">{@body}</p>
    </a>
    """
  end
end
