defmodule DstarDemoWeb.ExplainerComponents do
  @moduledoc """
  The long-form chrome shared by the `/explained/*` pages: the article
  shell, headings, prose, scroll steps and signal-driven tabs. Everything interactive here is a Datastar expression —
  no component in this module needs JavaScript of its own.
  """
  use Phoenix.Component

  import DstarDemoWeb.CoreComponents
  import DstarDemoWeb.DemoComponents, only: [code_block: 1, rich_text: 1]

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
          <nav class="flex items-center gap-4" aria-label="Site">
            <a
              href={~p"/explained"}
              class="text-sm font-medium text-base-content/70 transition hover:text-base-content"
            >
              Explained
            </a>
            <a
              href={~p"/showcase"}
              class="text-sm font-medium text-base-content/70 transition hover:text-base-content"
            >
              Showcase
            </a>
            <Layouts.theme_toggle />
          </nav>
        </header>

        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end

  attr :eyebrow, :string, required: true
  attr :title, :string, required: true
  attr :byline, :string, default: nil
  slot :dek, doc: "one sentence under the H1 for readers who arrive cold"
  slot :inner_block, required: true

  def lede(assigns) do
    ~H"""
    <div class="mx-auto mt-14 max-w-[68ch]">
      <p class="font-mono text-xs tracking-wide text-base-content/60 uppercase">
        <a href={~p"/explained"} class="transition hover:text-base-content">Explained</a>
        <span aria-hidden="true">·</span> {@eyebrow}
      </p>
      <h1 class="mt-3 text-4xl font-semibold tracking-tight text-balance sm:text-5xl">{@title}</h1>
      <p :if={@byline} id="byline-top" class="mt-3 text-sm text-base-content/60">{@byline}</p>
      <p
        :if={@dek != []}
        id="dek"
        class="mt-4 border-l-2 border-primary pl-4 text-base leading-7 text-base-content/75 [&_a]:font-medium [&_a]:underline [&_a]:decoration-base-content/30 [&_a]:underline-offset-2 [&_a:hover]:decoration-primary"
      >
        {render_slot(@dek)}
      </p>
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

  @doc "A plain underlined link for running prose. Keep the call on one line."
  attr :href, :string, required: true
  slot :inner_block, required: true

  def inline_link(assigns) do
    ~H"""
    <a
      href={@href}
      class="font-medium text-base-content underline decoration-base-content/30 underline-offset-2 transition hover:decoration-primary"
      phx-no-format
    >{render_slot(@inner_block)}</a>
    """
  end

  @doc """
  One scroll step. When half of its text is in view, `signal` becomes `n`,
  which is what drives the sticky diagram beside it.

  `:extra` renders below the text but isn't measured: Datastar's threshold
  is a share of the element, so a step made taller than two screens by
  unfolded code would otherwise never become the current stage.
  """
  attr :n, :integer, required: true
  attr :title, :string, required: true
  attr :signal, :string, default: "step"
  attr :id_prefix, :string, default: "xp-step"
  slot :inner_block, required: true
  slot :extra

  def step(assigns) do
    ~H"""
    <div
      id={"#{@id_prefix}-#{@n}"}
      class="flex min-h-[80vh] items-center py-10 first:min-h-[60vh] last:min-h-[70vh]"
    >
      <div
        class="w-full min-w-0 border-l-2 border-base-300 pl-5 transition duration-300"
        data-class={"{'!border-primary': $#{@signal} == #{@n}, 'opacity-50': $#{@signal} != #{@n}}"}
      >
        <div data-on-intersect__half={"$#{@signal} = #{@n}"}>
          <p class="font-mono text-xs text-base-content/60">{String.pad_leading("#{@n}", 2, "0")}</p>
          <h3 class="mt-1 text-xl font-semibold tracking-tight">{@title}</h3>
          <div class="mt-3 space-y-4 text-base leading-7 text-base-content/80 [&_code]:font-mono [&_code]:text-sm">
            {render_slot(@inner_block)}
          </div>
        </div>
        <div :if={@extra != []} class="mt-4 space-y-4">{render_slot(@extra)}</div>
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

  @doc """
  One file of a pull request, as a unified diff. `lines` is the diff text:
  each line starts with `+`, `-` or a space. Rendered as plain server-side
  text, so it's readable without JavaScript and by crawlers.
  """
  attr :file, :string, required: true
  attr :owner, :string, default: nil
  attr :lines, :string, required: true

  def diff_file(assigns) do
    assigns = assign(assigns, :rows, diff_rows(assigns.lines))

    ~H"""
    <figure class="min-w-0">
      <figcaption class="flex items-center justify-between gap-3 border border-b-0 border-base-300 bg-base-200 px-4 py-2 font-mono text-xs text-base-content/70">
        <span>{@file}</span>
        <span :if={@owner} class="font-sans">{@owner}</span>
      </figcaption>
      <pre
        tabindex="0"
        role="region"
        aria-label={@file}
        class="overflow-x-auto border border-base-300 bg-base-100 py-3 font-mono text-[13px] leading-6"
      ><code><span
        :for={{kind, text} <- @rows}
        class={[
          "block min-w-max px-4",
          kind == :add && "bg-primary/10 text-base-content",
          kind == :del && "bg-base-content/5 text-base-content/55 line-through decoration-base-content/30",
          kind == :same && "text-base-content/70"
        ]}
      ><span class="inline-block w-4 select-none text-base-content/50" aria-hidden="true">{diff_mark(kind)}</span>{text}</span></code></pre>
    </figure>
    """
  end

  defp diff_rows(lines) do
    lines
    |> String.trim_trailing()
    |> String.split("\n")
    |> Enum.map(fn
      "+" <> text -> {:add, text}
      "-" <> text -> {:del, text}
      " " <> text -> {:same, text}
      text -> {:same, text}
    end)
  end

  defp diff_mark(:add), do: "+"
  defp diff_mark(:del), do: "-"
  defp diff_mark(:same), do: " "

  @doc """
  The way out of an explainer: what to install, where the docs are, who
  wrote it. Every href here is checked by the page tests.
  """
  attr :id, :string, default: "try-dstar"
  attr :lab_link, :boolean, default: true
  slot :inner_block

  def try_dstar(assigns) do
    assigns = assign(assigns, :links, try_links())

    ~H"""
    <section id={@id} class="mx-auto mt-24 max-w-[860px]">
      <div class="max-w-[68ch]">
        <.section_heading>Try it</.section_heading>
        <.para :if={@inner_block != []}>{render_slot(@inner_block)}</.para>
        <.para>
          Dstar is a Hex package. Add it next to Phoenix, and a page is one module and one
          router line:
        </.para>
      </div>
      <div class="mt-5">
        <.code_block label="mix.exs" code={~s|{:dstar, "~> 0.3.0"}|} />
      </div>
      <ul class="mt-6 grid gap-px border border-base-300 bg-base-300 sm:grid-cols-2">
        <li :for={{href, title, body} <- @links} class="bg-base-100">
          <a
            href={href}
            class="group block h-full p-4 transition hover:bg-base-200 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary focus-visible:ring-inset"
          >
            <span class="flex items-center justify-between gap-2 text-sm font-semibold">
              {title}
              <span
                aria-hidden="true"
                class="text-base-content/40 transition group-hover:translate-x-0.5 group-hover:text-primary"
              >
                →
              </span>
            </span>
            <span class="mt-1 block text-sm leading-6 text-base-content/70">{body}</span>
          </a>
        </li>
      </ul>
      <.para :if={@lab_link}>
        Reading isn't proof. <.xp_link href={~p"/explained/lab"}>Now go break them</.xp_link>
      </.para>
      <p
        id="byline"
        class="mt-10 border-t border-base-300 pt-5 text-sm leading-6 text-base-content/70"
      >
        Built by <a
          href="https://rico.wtf"
          rel="author"
          class="font-medium text-base-content underline decoration-base-content/30 underline-offset-2 transition hover:decoration-primary"
        >Rico Trevisan</a>. Tell me where it breaks.
      </p>
    </section>
    """
  end

  @doc "The external links `try_dstar/1` renders, for tests that check they resolve."
  def try_links do
    [
      {"https://hexdocs.pm/dstar/readme.html#quick-start", "Quick start",
       "A counter page, end to end, in the README."},
      {"https://hexdocs.pm/dstar", "Documentation", "Every module and callback on HexDocs."},
      {"https://github.com/ricotrevisan/dstar", "Source",
       "The library on GitHub. Issues and PRs welcome."},
      {"https://github.com/ricotrevisan/dstar-demo", "This site's source",
       "Every page here, the benchmark included."}
    ]
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
