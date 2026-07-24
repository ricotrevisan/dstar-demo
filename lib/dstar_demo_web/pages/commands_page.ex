defmodule DstarDemoWeb.CommandsPage do
  use DstarDemoWeb, :dstar_page

  @impl Dstar.Page
  def mount(conn, _params) do
    assign(conn,
      intent: "idle",
      submitted: %{},
      validation: validate(%{})
    )
  end

  @impl Dstar.Page
  def render(assigns) do
    ~H"""
    <.demo_shell
      active="Form Validation"
      title="Form data validation"
      eyebrow="Form Data"
      summary="Datastar submits a real form with contentType: 'form'. The server validates the fields and patches only the status, field feedback, and submitted payload."
    >
      <:aside>
        <.demo_facts items={[
          "novalidate keeps the browser from intercepting the demo.",
          "contentType: 'form' sends form fields instead of Datastar signals.",
          "The inputs keep their values while server-owned feedback is patched.",
          "patch/3 updates status, field errors, summary, and payload fragments."
        ]} />
      </:aside>

      <section class="grid gap-5 xl:grid-cols-[minmax(0,1fr)_320px]">
        <form
          id="access-pass-form"
          novalidate
          data-on:submit={event("validate", opts: "{contentType: 'form'}")}
          data-on:reset={event("reset")}
          class="rounded-lg border border-zinc-800 bg-zinc-900 p-5 shadow-2xl shadow-zinc-950/50"
        >
          <input type="hidden" name="_csrf_token" value={Plug.CSRFProtection.get_csrf_token()} />

          <div class="mb-6 flex items-start justify-between gap-4">
            <div>
              <p class="text-xs font-semibold tracking-[0.16em] text-zinc-500 uppercase">
                Form surface
              </p>
              <h2 class="mt-2 text-2xl font-semibold text-zinc-50">Create an access pass</h2>
            </div>
            <.status_badge intent={@intent} />
          </div>

          <div class="grid gap-4">
            <.form_input
              label="Email"
              type="email"
              name="email"
              autocomplete="email"
              placeholder="ada@example.com"
              hint="Use an @example.com address."
              field={@validation["email"]}
              intent={@intent}
              required
            />
            <.form_input
              label="First name"
              name="first_name"
              autocomplete="given-name"
              placeholder="Ada"
              field={@validation["first_name"]}
              intent={@intent}
              minlength="2"
              required
            />
            <.form_input
              label="Last name"
              name="last_name"
              autocomplete="family-name"
              placeholder="Lovelace"
              field={@validation["last_name"]}
              intent={@intent}
              minlength="2"
              required
            />
          </div>

          <div class="mt-6 flex flex-wrap items-center gap-3">
            <button
              id="access-pass-submit"
              type="submit"
              class="inline-flex items-center gap-2 rounded-md bg-emerald-300 px-4 py-2.5 text-sm font-semibold text-zinc-950 transition hover:bg-emerald-200 focus:outline-none focus:ring-2 focus:ring-emerald-300/60"
            >
              <.icon name="hero-check-micro" class="size-4" /> Validate
            </button>
            <button
              id="access-pass-reset"
              type="reset"
              class="inline-flex items-center gap-2 rounded-md border border-zinc-700 px-4 py-2.5 text-sm font-semibold text-zinc-200 transition hover:border-zinc-500 hover:bg-zinc-800 focus:outline-none focus:ring-2 focus:ring-emerald-300/60"
            >
              <.icon name="hero-arrow-path-micro" class="size-4" /> Reset
            </button>
          </div>

          <.validation_panel validation={@validation} intent={@intent} />
        </form>

        <.payload_panel submitted={@submitted} />
      </section>
    </.demo_shell>
    """
  end

  @impl Dstar.Page
  def handle_event(conn, "validate", params) do
    validation = validate(params)
    intent = if ready?(validation), do: "accepted", else: "rejected"
    submitted = submitted_fields(params)

    conn
    |> patch(&status_badge/1, intent: intent)
    |> patch(&field_feedback/1,
      name: "email",
      hint: "Use an @example.com address.",
      field: validation["email"],
      intent: intent
    )
    |> patch(&field_feedback/1,
      name: "first_name",
      field: validation["first_name"],
      intent: intent
    )
    |> patch(&field_feedback/1,
      name: "last_name",
      field: validation["last_name"],
      intent: intent
    )
    |> patch(&validation_panel/1, validation: validation, intent: intent)
    |> patch(&payload_panel/1, submitted: submitted)
  end

  def handle_event(conn, "reset", _signals) do
    validation = validate(%{})

    conn
    |> patch(&status_badge/1, intent: "idle")
    |> patch(&field_feedback/1,
      name: "email",
      hint: "Use an @example.com address.",
      field: validation["email"],
      intent: "idle"
    )
    |> patch(&field_feedback/1,
      name: "first_name",
      field: validation["first_name"],
      intent: "idle"
    )
    |> patch(&field_feedback/1,
      name: "last_name",
      field: validation["last_name"],
      intent: "idle"
    )
    |> patch(&validation_panel/1, validation: validation, intent: "idle")
    |> patch(&payload_panel/1, submitted: %{})
  end

  attr :label, :string, required: true
  attr :type, :string, default: "text"
  attr :name, :string, required: true
  attr :autocomplete, :string, required: true
  attr :placeholder, :string, required: true
  attr :hint, :string, default: nil
  attr :field, :map, required: true
  attr :intent, :string, required: true
  attr :rest, :global, include: ~w(required minlength maxlength pattern)

  def form_input(assigns) do
    assigns =
      assigns
      |> Map.put(:input_id, "access-pass-#{assigns.name}-input")
      |> Map.put(:feedback_id, "access-pass-#{assigns.name}-feedback")

    ~H"""
    <label id={"access-pass-#{@name}-field"} class="block">
      <span class="mb-2 block text-sm font-medium text-zinc-300">{@label}</span>
      <input
        id={@input_id}
        type={@type}
        name={@name}
        autocomplete={@autocomplete}
        placeholder={@placeholder}
        aria-describedby={@feedback_id}
        class="w-full rounded-md border border-zinc-700 bg-zinc-950 px-3 py-3 text-base text-zinc-100 outline-none transition placeholder:text-zinc-600 focus:border-emerald-300 focus:ring-2 focus:ring-emerald-300/20"
        {@rest}
      />
      <.field_feedback name={@name} hint={@hint} field={@field} intent={@intent} />
    </label>
    """
  end

  attr :name, :string, required: true
  attr :hint, :string, default: nil
  attr :field, :map, required: true
  attr :intent, :string, required: true

  def field_feedback(assigns) do
    ~H"""
    <span
      id={"access-pass-#{@name}-feedback"}
      class={[
        "mt-2 block text-sm transition",
        @intent == "idle" && "text-zinc-500",
        @intent != "idle" && @field.valid && "text-emerald-300",
        @intent == "rejected" && !@field.valid && "text-rose-300"
      ]}
    >
      {field_feedback_message(@intent, @field, @hint)}
    </span>
    """
  end

  attr :intent, :string, required: true

  def status_badge(assigns) do
    ~H"""
    <span
      id="form-status"
      class={[
        "rounded-full px-3 py-1 text-xs font-medium",
        @intent == "accepted" && "bg-emerald-300 text-zinc-950",
        @intent == "rejected" && "bg-rose-400/15 text-rose-200",
        @intent == "idle" && "bg-zinc-800 text-zinc-300"
      ]}
    >
      {status_label(@intent)}
    </span>
    """
  end

  attr :submitted, :map, required: true

  def payload_panel(assigns) do
    assigns = Map.put(assigns, :submitted?, map_size(assigns.submitted) > 0)

    ~H"""
    <aside id="form-payload" class="rounded-lg border border-zinc-800 bg-zinc-950 p-4">
      <p class="text-xs font-semibold tracking-[0.16em] text-zinc-500 uppercase">
        Submitted form data
      </p>
      <div :if={@submitted?} class="mt-4 space-y-3 text-sm text-zinc-300">
        <div
          :for={name <- ~w(email first_name last_name)}
          class="flex items-center justify-between gap-3"
        >
          <span>{name}</span>
          <code class="truncate rounded bg-zinc-900 px-2 py-1 text-emerald-200">
            {Map.get(@submitted, name, "")}
          </code>
        </div>
      </div>
      <p :if={!@submitted?} class="mt-4 text-sm leading-6 text-zinc-400">
        No form data has reached the server yet.
      </p>
    </aside>
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
          {validation_title(@intent, @ready?)}
        </p>
        <span class={[
          "rounded-full px-2.5 py-1 text-xs font-semibold",
          @intent == "accepted" && "bg-emerald-300 text-zinc-950",
          @intent == "idle" && "bg-zinc-800 text-zinc-300",
          @intent == "rejected" && "bg-rose-400/15 text-rose-200"
        ]}>
          {validation_count(@intent, @validation)}
        </span>
      </div>
      <div class="mt-4 grid gap-2 text-sm text-zinc-400 sm:grid-cols-3">
        <.validation_chip label="email" field={@validation["email"]} intent={@intent} />
        <.validation_chip label="first" field={@validation["first_name"]} intent={@intent} />
        <.validation_chip label="last" field={@validation["last_name"]} intent={@intent} />
      </div>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :field, :map, required: true
  attr :intent, :string, required: true

  def validation_chip(assigns) do
    ~H"""
    <div class={[
      "rounded-md border px-3 py-2",
      @field.valid && @intent != "idle" &&
        "border-emerald-300/30 bg-emerald-300/10 text-emerald-100",
      !@field.valid && @intent == "rejected" && "border-rose-400/30 bg-rose-400/10 text-rose-100",
      (@intent == "idle" || (!@field.valid && @intent != "rejected")) &&
        "border-zinc-800 bg-zinc-900 text-zinc-400"
    ]}>
      <span class="font-medium">{@label}</span>
      <span class="mt-1 block text-xs opacity-80">{chip_message(@intent, @field)}</span>
    </div>
    """
  end

  defp validate(signals) do
    email = signals["email"] || ""
    first_name = signals["first_name"] || ""
    last_name = signals["last_name"] || ""

    %{
      "email" =>
        field(
          company_email?(email),
          "Company email accepted",
          "Use an @example.com email"
        ),
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

  defp company_email?(email) do
    email
    |> String.trim()
    |> String.downcase()
    |> String.ends_with?("@example.com")
  end

  defp submitted_fields(params) do
    Map.take(params, ~w(email first_name last_name))
  end

  defp status_label("accepted"), do: "accepted"
  defp status_label("rejected"), do: "server rejected"
  defp status_label(_intent), do: "not submitted"

  defp validation_title("idle", _ready?), do: "Waiting for the server to validate"
  defp validation_title("accepted", true), do: "Server accepted the form data"
  defp validation_title("rejected", _ready?), do: "Server found validation issues"
  defp validation_title(_intent, true), do: "Everything is valid"
  defp validation_title(_intent, false), do: "Still collecting valid data"

  defp validation_count("idle", _validation), do: "server on submit"
  defp validation_count("accepted", _validation), do: "accepted"
  defp validation_count(_intent, validation), do: "#{valid_count(validation)}/3 valid"

  defp field_feedback_message("idle", _field, hint), do: hint || "Server feedback appears here"
  defp field_feedback_message(_intent, field, _hint), do: field.message

  defp chip_message("idle", _field), do: "Server feedback appears here"
  defp chip_message(_intent, field), do: field.message

  defp valid_count(validation) do
    Enum.count(validation, fn {_key, field} -> field.valid end)
  end
end
