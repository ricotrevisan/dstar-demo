defmodule DstarDemoWeb.ExplainedIndexPage do
  @moduledoc """
  `/explained`: the list of long-form explainers, from `DstarDemoWeb.Explainers`.
  """
  use DstarDemoWeb, :dstar_page

  import DstarDemoWeb.ExplainerComponents

  @impl Dstar.Page
  def mount(conn, _params) do
    assign(conn,
      page_title: "Explained: LiveView and Dstar, side by side",
      meta: %{
        description:
          "Long-form explainers that build the same app with Phoenix LiveView and with Dstar, and count what each one asks of you.",
        path: ~p"/explained"
      },
      explainers: DstarDemoWeb.Explainers.all()
    )
  end

  @impl Dstar.Page
  def render(assigns) do
    ~H"""
    <.article_shell>
      <div class="mx-auto mt-14 max-w-[68ch]">
        <p class="font-mono text-xs tracking-wide text-base-content/60 uppercase">Explained</p>
        <h1 class="mt-3 text-4xl font-semibold tracking-tight sm:text-5xl">
          LiveView and Dstar, side by side
        </h1>
        <p class="mt-4 border-l-2 border-primary pl-4 text-base leading-7 text-base-content/75">
          <.inline_link href="https://hexdocs.pm/dstar">Dstar</.inline_link>
          renders Phoenix pages over <.inline_link href="https://data-star.dev">Datastar</.inline_link>:
          the browser sends signals, the server answers with HTML patches over SSE, and there's
          no client-side app. These posts build the same app both ways and count what each one
          asks of you.
        </p>
      </div>

      <ol
        id="explainers"
        class="mx-auto mt-12 max-w-[68ch] divide-y divide-base-300 border-y border-base-300"
      >
        <li :for={{e, i} <- Enum.with_index(@explainers, 1)} id={"explainer-#{i}"}>
          <a
            href={e.path}
            class="group grid grid-cols-[2.5rem_minmax(0,1fr)_auto] items-baseline gap-3 py-6 transition focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary"
          >
            <span class="font-mono text-xs text-base-content/60">
              {String.pad_leading("#{i}", 2, "0")}
            </span>
            <span>
              <span class="block font-mono text-xs tracking-wide text-base-content/60 uppercase">
                {e.kicker}
              </span>
              <span class="mt-1 block text-xl font-semibold tracking-tight transition group-hover:text-primary">
                {e.title}
              </span>
              <span class="mt-2 block text-sm leading-6 text-base-content/75">{e.summary}</span>
              <time
                datetime={Date.to_iso8601(e.published)}
                class="mt-2 block font-mono text-[11px] text-base-content/55"
              >
                {Calendar.strftime(e.published, "%B %-d, %Y")}
              </time>
            </span>
            <span
              aria-hidden="true"
              class="text-base-content/40 transition group-hover:translate-x-0.5 group-hover:text-primary"
            >
              →
            </span>
          </a>
        </li>
      </ol>
    </.article_shell>

    <Layouts.flash_group flash={@flash} />
    """
  end
end
