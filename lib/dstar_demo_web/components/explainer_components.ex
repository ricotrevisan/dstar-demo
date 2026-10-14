defmodule DstarDemoWeb.ExplainerComponents do
  @moduledoc """
  The long-form chrome shared by the `/explained/*` pages: the article
  shell, headings, prose, scroll steps and signal-driven tabs. Everything interactive here is a Datastar expression —
  no component in this module needs JavaScript of its own.
  """
  use Phoenix.Component

  import DstarDemoWeb.CoreComponents
  import DstarDemoWeb.DemoComponents, only: [rich_text: 1]

  alias DstarDemoWeb.Layouts

  use Phoenix.VerifiedRoutes,
    endpoint: DstarDemoWeb.Endpoint,
    router: DstarDemoWeb.Router,
    statics: DstarDemoWeb.static_paths()

  attr :signals, :map, default: %{}
  attr :rest, :global
  slot :inner_block, required: true

  def article_shell(assigns) do
    ~H"""
    <div
      class="min-h-screen bg-base-100 text-base-content"
      data-signals={@signals != %{} && Jason.encode!(@signals)}
      {@rest}
    >
      <div class="mx-auto w-full max-w-[1100px] px-5 py-10 sm:px-8">
        <header class="flex flex-wrap items-center justify-between gap-3 border-b border-base-300 pb-5">
          <a href={~p"/"} class="flex items-center gap-2.5 text-sm font-semibold tracking-tight">
            <span class="grid size-7 place-items-center bg-primary text-primary-content">
              <.icon name="hero-bolt-micro" class="size-4" />
            </span>
            Dstar Demo
          </a>
          <Layouts.theme_toggle />
        </header>

        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end

  attr :eyebrow, :string, required: true
  attr :title, :string, required: true
  slot :inner_block, required: true

  def lede(assigns) do
    ~H"""
    <div class="mx-auto mt-14 max-w-[68ch]">
      <p class="font-mono text-xs tracking-wide text-base-content/60 uppercase">{@eyebrow}</p>
      <h1 class="mt-3 text-4xl font-semibold tracking-tight sm:text-5xl">{@title}</h1>
      <div class="mt-6 text-lg leading-8 text-base-content/80 [&_code]:font-mono [&_code]:text-base [&>p+p]:mt-5">
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end

  attr :id, :string, default: nil
  attr :class, :string, default: nil
  slot :inner_block, required: true

  def section_heading(assigns) do
    ~H"""
    <h2
      id={@id}
      class={[
        "scroll-mt-8 border-b border-base-300 pb-2 text-2xl font-semibold tracking-tight",
        @class
      ]}
    >
      {render_slot(@inner_block)}
    </h2>
    """
  end

  attr :class, :string, default: nil
  slot :inner_block, required: true

  def para(assigns) do
    ~H"""
    <p class={[
      "mt-5 text-base leading-7 text-base-content/80 [&_code]:font-mono [&_code]:text-sm",
      @class
    ]}>
      {render_slot(@inner_block)}
    </p>
    """
  end

  attr :href, :string, required: true
  slot :inner_block, required: true

  def xp_link(assigns) do
    ~H"""
    <a
      href={@href}
      class="font-medium underline decoration-base-content/30 underline-offset-2 transition hover:decoration-primary"
    >
      {render_slot(@inner_block)} <span aria-hidden="true">→</span>
    </a>
    """
  end

  @doc """
  One scroll step. Crossing half its height sets `signal` to `n`, which is
  what drives the sticky diagram beside it.
  """
  attr :n, :integer, required: true
  attr :title, :string, required: true
  attr :signal, :string, default: "step"
  attr :id_prefix, :string, default: "xp-step"
  slot :inner_block, required: true

  def step(assigns) do
    ~H"""
    <div
      id={"#{@id_prefix}-#{@n}"}
      class="flex min-h-[80vh] items-center py-10 first:min-h-[60vh] last:min-h-[70vh]"
      data-on-intersect__half={"$#{@signal} = #{@n}"}
    >
      <div
        class="border-l-2 border-base-300 pl-5 transition duration-300"
        data-class={"{'!border-primary': $#{@signal} == #{@n}, 'opacity-50': $#{@signal} != #{@n}}"}
      >
        <p class="font-mono text-xs text-base-content/60">{String.pad_leading("#{@n}", 2, "0")}</p>
        <h3 class="mt-1 text-xl font-semibold tracking-tight">{@title}</h3>
        <div class="mt-3 space-y-4 text-base leading-7 text-base-content/80 [&_code]:font-mono [&_code]:text-sm">
          {render_slot(@inner_block)}
        </div>
      </div>
    </div>
    """
  end

  attr :signal, :string, required: true
  attr :key, :string, required: true
  attr :label, :string, required: true

  def tab_button(assigns) do
    ~H"""
    <button
      type="button"
      role="tab"
      class="-mb-px border-b-2 border-transparent px-4 py-2.5 text-sm font-medium text-base-content/60 transition hover:text-base-content focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary"
      data-on:click={"$#{@signal} = '#{@key}'"}
      data-class={"{'!border-primary !text-base-content': $#{@signal} == '#{@key}'}"}
      data-attr:aria-selected={"$#{@signal} == '#{@key}'"}
    >
      {@label}
    </button>
    """
  end

  attr :title, :string, required: true
  attr :tone, :string, required: true
  attr :items, :list, required: true

  def verdict(assigns) do
    ~H"""
    <div class="border-r border-b border-base-300 p-5">
      <h3 class="flex items-center gap-2 text-base font-semibold tracking-tight">
        <.swatch tone={@tone} />
        {@title}
      </h3>
      <ul class="mt-4 space-y-3">
        <li :for={item <- @items} class="text-sm leading-6 text-base-content/80">
          <.rich_text text={item} />
        </li>
      </ul>
    </div>
    """
  end

  @doc "The square that marks Dstar (primary) or LiveView (neutral) throughout."
  attr :tone, :string, required: true

  def swatch(assigns) do
    ~H"""
    <span
      class={[
        "inline-block size-2 shrink-0",
        @tone == "primary" && "bg-primary",
        @tone != "primary" && "bg-base-content/40"
      ]}
      aria-hidden="true"
    >
    </span>
    """
  end
end
