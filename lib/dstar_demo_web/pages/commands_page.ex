defmodule DstarDemoWeb.CommandsPage do
  use DstarDemoWeb, :dstar_page

  @impl Dstar.Page
  def mount(conn, _params) do
    assign(conn,
      email: "",
      first_name: "",
      last_name: "",
      intent: "editing",
      validation: validate(%{})
    )
  end

  @impl Dstar.Page
  def render(assigns) do
    ~H"""
    <.demo_shell
      active="Command Validation"
      title="Validation is a command"
      eyebrow="Command Validation"
      summary="Inputs bind to Datastar signals. The server validates on signal patches and treats readiness as explicit user intent."
      signals={
        %{
          email: @email,
          first_name: @first_name,
          last_name: @last_name,
          intent: @intent,
          validation: @validation
        }
      }
      data-on-signal-patch__debounce.300ms={event("validate")}
      data-on-signal-patch-filter="{include: /^(email|first_name|last_name)$/}"
    >
      <:aside>
        <.demo_facts items={[
          "No form element, only data-bind inputs and command buttons.",
          "use Dstar.Page colocates render/1 and handle_event/3.",
          "The page's _event route starts SSE before handle_event/3 runs.",
          "patch/3 re-renders the validation UI from function components."
        ]} />
      </:aside>

      <section class="grid gap-5 xl:grid-cols-[minmax(0,1fr)_320px]">
        <div
          id="command-demo"
          class="rounded-lg border border-zinc-800 bg-zinc-900 p-5 shadow-2xl shadow-zinc-950/50"
        >
          <div class="mb-6 flex items-start justify-between gap-4">
            <div>
              <p class="text-xs font-semibold tracking-[0.16em] text-zinc-500 uppercase">
                Command surface
              </p>
              <h2 class="mt-2 text-2xl font-semibold text-zinc-50">Create an access pass</h2>
            </div>
            <span
              id="intent-pill"
              class="rounded-full bg-zinc-800 px-3 py-1 text-xs font-medium text-zinc-300"
            >
              {@intent}
            </span>
          </div>

          <div class="grid gap-4">
            <.bound_input
              label="Email"
              autocomplete="email"
              bind="email"
              placeholder="ada@example.com"
              value={@email}
              field={@validation["email"]}
            />
            <.bound_input
              label="First name"
              autocomplete="given-name"
              bind="first_name"
              placeholder="Ada"
              value={@first_name}
              field={@validation["first_name"]}
            />
            <.bound_input
              label="Last name"
              autocomplete="family-name"
              bind="last_name"
              placeholder="Lovelace"
              value={@last_name}
              field={@validation["last_name"]}
            />
          </div>

          <div class="mt-6 flex flex-wrap items-center gap-3">
            <button
              id="command-ready"
              data-on:click={event("ready")}
              class="inline-flex items-center gap-2 rounded-md bg-emerald-300 px-4 py-2.5 text-sm font-semibold text-zinc-950 transition hover:bg-emerald-200 focus:outline-none focus:ring-2 focus:ring-emerald-300/60"
            >
              <.icon name="hero-check-micro" class="size-4" /> Ready
            </button>
            <button
              id="command-reset"
              data-on:click={event("reset")}
              class="inline-flex items-center gap-2 rounded-md border border-zinc-700 px-4 py-2.5 text-sm font-semibold text-zinc-200 transition hover:border-zinc-500 hover:bg-zinc-800 focus:outline-none focus:ring-2 focus:ring-emerald-300/60"
            >
              <.icon name="hero-arrow-path-micro" class="size-4" /> Reset
            </button>
          </div>

          <.validation_panel validation={@validation} intent={@intent} />
        </div>

        <aside class="rounded-lg border border-zinc-800 bg-zinc-950 p-4">
          <p class="text-xs font-semibold tracking-[0.16em] text-zinc-500 uppercase">
            Signal flow
          </p>
          <div class="mt-4 space-y-3 text-sm text-zinc-300">
            <div class="flex items-center justify-between gap-3">
              <span>email</span>
              <code class="truncate rounded bg-zinc-900 px-2 py-1 text-emerald-200">{@email}</code>
            </div>
            <div class="flex items-center justify-between gap-3">
              <span>first_name</span>
              <code class="truncate rounded bg-zinc-900 px-2 py-1 text-emerald-200">
                {@first_name}
              </code>
            </div>
            <div class="flex items-center justify-between gap-3">
              <span>last_name</span>
              <code class="truncate rounded bg-zinc-900 px-2 py-1 text-emerald-200">
                {@last_name}
              </code>
            </div>
          </div>
        </aside>
      </section>
    </.demo_shell>
    """
  end

  @impl Dstar.Page
  def handle_event(conn, "validate", signals) do
    validation = validate(signals)

    conn
    |> patch_signals(%{validation: validation, intent: "editing"})
    |> patch(&validation_panel/1, validation: validation, intent: "editing")
    |> patch(&intent_pill/1, intent: "editing")
  end

  def handle_event(conn, "ready", signals) do
    validation = validate(signals)
    intent = if ready?(validation), do: "ready", else: "blocked"

    conn
    |> patch_signals(%{validation: validation, intent: intent})
    |> patch(&validation_panel/1, validation: validation, intent: intent)
    |> patch(&intent_pill/1, intent: intent)
  end

  # Known trade-off: echoing the cleared inputs passes the signal-patch
  # filter and re-fires one redundant (idempotent) validate ~300ms after a
  # reset from a non-empty state. Clearing them client-side instead would
  # arm the same debounce, so the extra round-trip is accepted.
  def handle_event(conn, "reset", _signals) do
    validation = validate(%{})

    conn
    |> patch_signals(%{
      email: "",
      first_name: "",
      last_name: "",
      validation: validation,
      intent: "editing"
    })
    |> patch(&validation_panel/1, validation: validation, intent: "editing")
    |> patch(&intent_pill/1, intent: "editing")
  end

  attr :label, :string, required: true
  attr :autocomplete, :string, required: true
  attr :bind, :string, required: true
  attr :placeholder, :string, required: true
  attr :value, :string, required: true
  attr :field, :map, required: true

  def bound_input(assigns) do
    assigns =
      Map.put(assigns, :bind_attrs, [
        {String.to_atom("data-bind:#{assigns.bind}"), ""}
      ])

    ~H"""
    <label class="block">
      <span class="mb-2 block text-sm font-medium text-zinc-300">{@label}</span>
      <input
        autocomplete={@autocomplete}
        placeholder={@placeholder}
        value={@value}
        {@bind_attrs}
        class={[
          "w-full rounded-md border bg-zinc-950 px-3 py-3 text-base text-zinc-100 outline-none transition placeholder:text-zinc-600",
          @field.valid && "border-zinc-700 focus:border-emerald-300",
          !@field.valid && "border-rose-400 focus:border-rose-300"
        ]}
      />
      <span class={[
        "mt-2 block text-sm",
        @field.valid && "text-zinc-500",
        !@field.valid && "text-rose-300"
      ]}>
        {@field.message}
      </span>
    </label>
    """
  end

  attr :validation, :map, required: true
  attr :intent, :string, required: true

  def validation_panel(assigns) do
    assigns = Map.put(assigns, :ready?, ready?(assigns.validation))

    ~H"""
    <div id="validation-panel" class="mt-6 rounded-md border border-zinc-800 bg-zinc-950 p-4">
      <div class="flex items-center justify-between gap-4">
        <p class="text-sm font-semibold text-zinc-200">
          {if @ready?, do: "Everything is valid", else: "Still collecting valid data"}
        </p>
        <span class={[
          "rounded-full px-2.5 py-1 text-xs font-semibold",
          @ready? && @intent == "ready" && "bg-emerald-300 text-zinc-950",
          @ready? && @intent != "ready" && "bg-emerald-300/15 text-emerald-200",
          !@ready? && "bg-rose-400/15 text-rose-200"
        ]}>
          {if @ready? && @intent == "ready", do: "ready", else: "#{valid_count(@validation)}/3 valid"}
        </span>
      </div>
      <div class="mt-4 grid gap-2 text-sm text-zinc-400 sm:grid-cols-3">
        <.validation_chip label="email" field={@validation["email"]} />
        <.validation_chip label="first" field={@validation["first_name"]} />
        <.validation_chip label="last" field={@validation["last_name"]} />
      </div>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :field, :map, required: true

  def validation_chip(assigns) do
    ~H"""
    <div class={[
      "rounded-md border px-3 py-2",
      @field.valid && "border-emerald-300/30 bg-emerald-300/10 text-emerald-100",
      !@field.valid && "border-zinc-800 bg-zinc-900 text-zinc-400"
    ]}>
      <span class="font-medium">{@label}</span>
    </div>
    """
  end

  attr :intent, :string, required: true

  def intent_pill(assigns) do
    ~H"""
    <span
      id="intent-pill"
      class={[
        "rounded-full px-3 py-1 text-xs font-medium",
        @intent == "ready" && "bg-emerald-300 text-zinc-950",
        @intent == "blocked" && "bg-rose-400/15 text-rose-200",
        @intent == "editing" && "bg-zinc-800 text-zinc-300"
      ]}
    >
      {@intent}
    </span>
    """
  end

  defp validate(signals) do
    email = signals["email"] || ""
    first_name = signals["first_name"] || ""
    last_name = signals["last_name"] || ""

    %{
      "email" => field(String.contains?(email, "@"), "Email includes @", "Email needs an @"),
      "first_name" =>
        field(
          String.length(String.trim(first_name)) >= 2,
          "First name is set",
          "Use at least 2 characters"
        ),
      "last_name" =>
        field(
          String.length(String.trim(last_name)) >= 2,
          "Last name is set",
          "Use at least 2 characters"
        )
    }
  end

  defp field(true, good, _bad), do: %{valid: true, message: good}
  defp field(false, _good, bad), do: %{valid: false, message: bad}

  defp ready?(validation), do: Enum.all?(validation, fn {_key, field} -> field.valid end)

  defp valid_count(validation) do
    Enum.count(validation, fn {_key, field} -> field.valid end)
  end
end
