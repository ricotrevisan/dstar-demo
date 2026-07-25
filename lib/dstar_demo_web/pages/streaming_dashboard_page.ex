defmodule DstarDemoWeb.StreamingDashboardPage do
  use DstarDemoWeb, :dstar_page

  @stream_steps 8
  @stream_delay if Mix.env() == :test, do: 0, else: 280

  @impl Dstar.Page
  def mount(conn, _params) do
    assign(conn,
      streamStatus: "idle",
      tick: 0,
      throughput: 118,
      latency: 42,
      progress: 0
    )
  end

  # POST /streaming — Dstar.Page.Plug opens the SSE stream (deduplicated
  # per tab via stream_key/1) and then owns the receive loop.
  @impl Dstar.Page
  def stream_key(_conn), do: {:dstar_demo, :streaming_dashboard}

  @impl Dstar.Page
  def handle_connect(conn, _params) do
    Process.send_after(self(), {:tick, 1}, @stream_delay)

    conn
    |> patch_signals(%{streamStatus: "live", progress: 0, tick: 0})
    |> patch(&stream_frame/1, [tick: 0, status: "live"], selector: "#stream-frame")
  end

  @impl Dstar.Page
  def handle_info({:tick, tick}, conn) when tick <= @stream_steps do
    case check_connection(conn) do
      {:ok, conn} ->
        throughput = 118 + tick * 9 + rem(tick, 3) * 4
        latency = 42 - min(tick * 2, 18)
        progress = trunc(tick / @stream_steps * 100)

        Process.send_after(self(), {:tick, tick + 1}, @stream_delay)

        conn
        |> patch_signals(%{
          tick: tick,
          throughput: throughput,
          latency: latency,
          progress: progress,
          streamStatus: "live"
        })
        |> patch(&metric_tile/1,
          id: "metric-throughput",
          title: "Throughput",
          value: "#{throughput}/min",
          detail: "ingested events",
          tone: "good"
        )
        |> patch(&metric_tile/1,
          id: "metric-latency",
          title: "Latency",
          value: "#{latency} ms",
          detail: "edge to patch",
          tone: "info"
        )
        |> patch(&metric_tile/1,
          id: "metric-progress",
          title: "Progress",
          value: "#{progress}%",
          detail: "stream live",
          tone: "warn"
        )
        |> patch(&activity_row/1, [tick: tick], selector: "#activity-log", mode: :prepend)

      {:error, conn} ->
        {:halt, conn}
    end
  end

  def handle_info({:tick, _done}, conn) do
    conn =
      conn
      |> patch_signals(%{streamStatus: "complete", progress: 100})
      |> patch(&stream_frame/1, [tick: @stream_steps, status: "complete"],
        selector: "#stream-frame"
      )

    {:halt, conn}
  end

  @impl Dstar.Page
  def render(assigns) do
    assigns = Map.put(assigns, :snippet, DstarDemoWeb.Snippets.fetch!(:streaming_dashboard))

    ~H"""
    <.demo_shell
      active="Streaming Dashboard"
      title="Streaming dashboard"
      summary="A bounded SSE loop sends live metrics and activity patches. Starting it again in the same tab replaces the prior stream."
      signals={
        %{
          streamStatus: @streamStatus,
          tick: @tick,
          throughput: @throughput,
          latency: @latency,
          progress: @progress
        }
      }
    >
      <:demo>
        <section
          id="stream-dashboard"
          data-on:online__window={connect(opts: "{retryMaxCount: 0}")}
          class="grid gap-5"
        >
          <div class="flex flex-wrap items-center justify-between gap-3 border border-base-300 bg-base-200 p-4">
            <div>
              <p class="text-sm font-semibold text-base-content">Live operations lane</p>
              <p class="mt-1 text-sm text-base-content/70">
                Bounded demo stream, safe to restart repeatedly.
              </p>
            </div>
            <button
              id="start-stream"
              data-on:click={connect(opts: "{retryMaxCount: 0}")}
              class="inline-flex items-center gap-2 rounded-md border border-primary bg-primary px-4 py-2.5 text-sm font-medium text-primary-content transition hover:bg-primary/90 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary"
            >
              <.icon name="hero-play-micro" class="size-4" /> Start stream
            </button>
          </div>

          <div id="metric-grid" class="grid gap-3 md:grid-cols-3">
            <.metric_tile
              id="metric-throughput"
              title="Throughput"
              value={"#{@throughput}/min"}
              detail="ingested events"
              tone="good"
            />
            <.metric_tile
              id="metric-latency"
              title="Latency"
              value={"#{@latency} ms"}
              detail="edge to patch"
              tone="info"
            />
            <.metric_tile
              id="metric-progress"
              title="Progress"
              value={"#{@progress}%"}
              detail={"stream #{@streamStatus}"}
              tone="warn"
            />
          </div>

          <.stream_frame tick={@tick} status={@streamStatus} />
        </section>
      </:demo>

      <:how_it_works>
        <.key_points items={[
          "connect/1 posts to the page path and opens the stream.",
          "stream_key/1 deduplicates by demo scope plus tabId.",
          "handle_info/2 receives ticks from the library-owned loop.",
          "Metric tiles and activity rows are patched independently."
        ]} />

        <.prose>
          <code class="font-mono text-sm">connect/1</code>
          posts to the page path and <code class="font-mono text-sm">Dstar.Page.Plug</code>
          opens a server-sent event stream, then owns the receive loop.
          <code class="font-mono text-sm">stream_key/1</code>
          registers it per demo scope plus tab, so starting it again in the same tab replaces the
          old stream instead of running two. Each tick patches the three metric tiles and prepends
          one activity row; the final tick returns <code class="font-mono text-sm">{"{:halt, conn}"}</code>.
        </.prose>

        <div class="mt-6">
          <.code_block
            language={@snippet.wiring_language}
            label={@snippet.source}
            code={@snippet.wiring}
          />
        </div>
      </:how_it_works>
    </.demo_shell>
    """
  end

  attr :tick, :integer, required: true
  attr :status, :string, required: true

  def stream_frame(assigns) do
    ~H"""
    <div id="stream-frame" class="grid gap-5 xl:grid-cols-[minmax(0,1fr)_320px]">
      <section class="border border-base-300 bg-base-200 p-4">
        <div class="flex items-center justify-between gap-3">
          <div>
            <p class="text-sm font-semibold text-base-content">Activity stream</p>
            <p class="mt-1 font-mono text-xs text-base-content/65">latest tick: {@tick}</p>
          </div>
          <.pill label={@status} tone={if(@status == "complete", do: "good", else: "info")} />
        </div>

        <div id="activity-log" class="mt-4 space-y-2">
          <.activity_row tick={@tick} />
        </div>
      </section>

      <aside class="border border-base-300 bg-base-100 p-4">
        <p class="font-mono text-xs tracking-wide text-base-content/65 uppercase">
          Deduplication
        </p>
        <p class="mt-3 text-sm leading-6 text-base-content/70">
          The body exposes a per-tab signal named tabId. stream_key/1 registers this
          connection and replaces any older stream for the same tab.
        </p>
      </aside>
    </div>
    """
  end

  attr :tick, :integer, required: true

  def activity_row(assigns) do
    tick = assigns.tick

    assigns =
      assigns
      |> Map.put(
        :phase,
        Enum.at(["queued", "validated", "patched", "broadcast"], rem(tick, 4))
      )
      |> Map.put(:severity, Enum.at(["good", "info", "warn"], rem(tick, 3)))

    ~H"""
    <div
      id={"activity-#{@tick}"}
      class="flex items-center justify-between gap-3 border border-base-300 bg-base-100 px-3 py-2"
    >
      <div class="min-w-0">
        <p class="truncate text-sm font-medium text-base-content">Patch cycle {@tick} {@phase}</p>
        <p class="text-xs text-base-content/65">server-sent event delivered to this tab</p>
      </div>
      <.pill label={"t+#{@tick}"} tone={@severity} />
    </div>
    """
  end
end
