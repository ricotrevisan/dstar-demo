defmodule DstarDemoWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use DstarDemoWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <header class="navbar px-4 sm:px-6 lg:px-8">
      <div class="flex-1">
        <a href="/" class="flex-1 flex w-fit items-center gap-2">
          <img src={~p"/images/logo.svg"} width="36" />
          <span class="text-sm font-semibold">v{Application.spec(:phoenix, :vsn)}</span>
        </a>
      </div>
      <div class="flex-none">
        <ul class="flex flex-column px-1 space-x-4 items-center">
          <li>
            <a href="https://phoenixframework.org/" class="btn btn-ghost">Website</a>
          </li>
          <li>
            <a href="https://github.com/phoenixframework/phoenix" class="btn btn-ghost">GitHub</a>
          </li>
          <li>
            <.theme_toggle />
          </li>
          <li>
            <a href="https://hexdocs.pm/phoenix/overview.html" class="btn btn-primary">
              Get Started <span aria-hidden="true">&rarr;</span>
            </a>
          </li>
        </ul>
      </div>
    </header>

    <main class="px-4 py-20 sm:px-6 lg:px-8">
      <div class="mx-auto max-w-2xl space-y-4">
        {render_slot(@inner_block)}
      </div>
    </main>

    <.flash_group flash={@flash} />
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  The buttons dispatch `phx:set-theme` with a Datastar expression, which
  assets/js/app.js handles, so the toggle doesn't need the LiveView client.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div
      class="relative flex items-center rounded-full border border-base-300 bg-base-200 p-1 text-base-content/60"
      role="group"
      aria-label="Theme"
    >
      <%!-- The "system" setting REMOVES data-theme (see setTheme in app.js), so
      the scaffold's [[data-theme=system]_&] selector could never match and the
      system icon stayed dim while selected. :root:not([data-theme]) is the
      condition that actually holds. --%>
      <div class="absolute top-1 bottom-1 w-8 rounded-full bg-primary transition-[left] left-1 [[data-theme=light]_&]:left-9 [[data-theme=dark]_&]:left-[4.25rem]" />

      <button
        class="relative grid size-8 cursor-pointer place-items-center rounded-full transition hover:text-base-content focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary [:root:not([data-theme])_&]:text-primary-content"
        data-on:click="el.dispatchEvent(new CustomEvent('phx:set-theme', {bubbles: true}))"
        data-phx-theme="system"
        title="System theme"
        aria-label="Use the system theme"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4" />
      </button>

      <button
        class="relative grid size-8 cursor-pointer place-items-center rounded-full transition hover:text-base-content focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary [[data-theme=light]_&]:text-primary-content"
        data-on:click="el.dispatchEvent(new CustomEvent('phx:set-theme', {bubbles: true}))"
        data-phx-theme="light"
        title="Light theme"
        aria-label="Use the light theme"
      >
        <.icon name="hero-sun-micro" class="size-4" />
      </button>

      <button
        class="relative grid size-8 cursor-pointer place-items-center rounded-full transition hover:text-base-content focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary [[data-theme=dark]_&]:text-primary-content"
        data-on:click="el.dispatchEvent(new CustomEvent('phx:set-theme', {bubbles: true}))"
        data-phx-theme="dark"
        title="Dark theme"
        aria-label="Use the dark theme"
      >
        <.icon name="hero-moon-micro" class="size-4" />
      </button>
    </div>
    """
  end
end
