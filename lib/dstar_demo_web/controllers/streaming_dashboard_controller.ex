defmodule DstarDemoWeb.StreamingDashboardController do
  use DstarDemoWeb, :dstar

  @stream_steps 8
  @stream_delay if Mix.env() == :test, do: 0, else: 280

  @impl Dstar
  def mount(conn, _params) do
    conn
    |> signal(:streamStatus, "idle")
    |> signal(:tick, 0)
    |> signal(:throughput, 118)
    |> signal(:latency, 42)
    |> signal(:progress, 0)
  end

  def home(conn, _params), do: conn

  def stream(conn, _params) do
    conn =
      conn
      |> normalize_tab_id()
      |> Dstar.start_stream({:dstar_demo, :streaming_dashboard})
      |> Dstar.patch_signals(%{streamStatus: "live", progress: 0, tick: 0})
      |> Dstar.patch_elements(stream_frame(%{tick: 0, status: "live"}), selector: "#stream-frame")

    stream_loop(conn, 1)
  end

  @impl Dstar
  def render(assigns) do
    ~H"""
    <.demo_shell
      active="Streaming Dashboard"
      title="Streaming dashboard"
      eyebrow="SSE stream"
      summary="A bounded SSE loop sends live metrics and activity patches. Starting it again in the same tab replaces the prior stream."
      signals={init_signals(@conn)}
    >
      <:aside>
        <.demo_facts items={[
          "The stream action calls Dstar.start_stream/2.",
          "StreamRegistry deduplicates by demo scope plus tabId.",
          "The loop is bounded and checks the SSE connection.",
          "Metric tiles and activity rows are patched independently."
        ]} />
      </:aside>

      <section
        id="stream-dashboard"
        data-on:online__window="@post('/streaming/stream', {retryMaxCount: 0})"
        class="grid gap-5"
      >
        <div class="flex flex-wrap items-center justify-between gap-3 rounded-lg border border-zinc-800 bg-zinc-900 p-4">
          <div>
            <p class="text-sm font-semibold text-zinc-100">Live operations lane</p>
            <p class="mt-1 text-sm text-zinc-500">
              Bounded demo stream, safe to restart repeatedly.
            </p>
          </div>
          <button
            id="start-stream"
            data-on:click="@post('/streaming/stream', {retryMaxCount: 0})"
            class="inline-flex items-center gap-2 rounded-md bg-emerald-300 px-4 py-2.5 text-sm font-semibold text-zinc-950 transition hover:bg-emerald-200 focus:outline-none focus:ring-2 focus:ring-emerald-300/60"
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
    </.demo_shell>
    """
  end

  attr :tick, :integer, required: true
  attr :status, :string, required: true

  def stream_frame(assigns) do
    ~H"""
    <div id="stream-frame" class="grid gap-5 xl:grid-cols-[minmax(0,1fr)_320px]">
      <section class="rounded-lg border border-zinc-800 bg-zinc-900 p-4">
        <div class="flex items-center justify-between gap-3">
          <div>
            <p class="text-sm font-semibold text-zinc-100">Activity stream</p>
            <p class="mt-1 text-xs text-zinc-500">latest tick: {@tick}</p>
          </div>
          <.pill label={@status} tone={if(@status == "complete", do: "good", else: "info")} />
        </div>

        <div id="activity-log" class="mt-4 space-y-2">
          <.activity_row tick={@tick} />
        </div>
      </section>

      <aside class="rounded-lg border border-zinc-800 bg-zinc-950 p-4">
        <p class="text-xs font-semibold tracking-[0.16em] text-zinc-500 uppercase">
          Deduplication
        </p>
        <p class="mt-3 text-sm leading-6 text-zinc-400">
          The body exposes a per-tab signal named tabId. Dstar.start_stream/2 registers this
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
      class="flex items-center justify-between gap-3 rounded-md border border-zinc-800 bg-zinc-950 px-3 py-2"
    >
      <div class="min-w-0">
        <p class="truncate text-sm font-medium text-zinc-100">Patch cycle {@tick} {@phase}</p>
        <p class="text-xs text-zinc-500">server-sent event delivered to this tab</p>
      </div>
      <.pill label={"t+#{@tick}"} tone={@severity} />
    </div>
    """
  end

  defp stream_loop(conn, tick) when tick <= @stream_steps do
    case Dstar.check_connection(conn) do
      {:ok, conn} ->
        if @stream_delay > 0, do: Process.sleep(@stream_delay)

        throughput = 118 + tick * 9 + rem(tick, 3) * 4
        latency = 42 - min(tick * 2, 18)
        progress = trunc(tick / @stream_steps * 100)

        conn =
          conn
          |> Dstar.patch_signals(%{
            tick: tick,
            throughput: throughput,
            latency: latency,
            progress: progress,
            streamStatus: "live"
          })
          |> Dstar.patch_elements(
            metric_tile(%{
              id: "metric-throughput",
              title: "Throughput",
              value: "#{throughput}/min",
              detail: "ingested events",
              tone: "good"
            }),
            []
          )
          |> Dstar.patch_elements(
            metric_tile(%{
              id: "metric-latency",
              title: "Latency",
              value: "#{latency} ms",
              detail: "edge to patch",
              tone: "info"
            }),
            []
          )
          |> Dstar.patch_elements(
            metric_tile(%{
              id: "metric-progress",
              title: "Progress",
              value: "#{progress}%",
              detail: "stream live",
              tone: "warn"
            }),
            []
          )
          |> Dstar.patch_elements(activity_row(%{tick: tick}),
            selector: "#activity-log",
            mode: :prepend
          )

        stream_loop(conn, tick + 1)

      {:error, conn} ->
        conn
    end
  end

  defp stream_loop(conn, _tick) do
    conn
    |> Dstar.patch_signals(%{streamStatus: "complete", progress: 100})
    |> Dstar.patch_elements(stream_frame(%{tick: @stream_steps, status: "complete"}),
      selector: "#stream-frame"
    )
  end

  defp normalize_tab_id(%Plug.Conn{body_params: body_params, params: params} = conn)
       when is_map(body_params) do
    case {body_params["tabId"], body_params["tabid"]} do
      {nil, tab_id} when is_binary(tab_id) ->
        %{
          conn
          | body_params: Map.put(body_params, "tabId", tab_id),
            params: Map.put(params, "tabId", tab_id)
        }

      _ ->
        conn
    end
  end

  defp normalize_tab_id(conn), do: conn
end
