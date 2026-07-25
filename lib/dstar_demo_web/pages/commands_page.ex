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
    assigns = Map.put(assigns, :snippet, DstarDemoWeb.Snippets.fetch!(:commands))

    ~H"""
    <.demo_shell
      active="Form Validation"
      title="Form data validation"
      summary="Datastar submits a real form with contentType: 'form'. The server validates the fields and patches only the status, field feedback, and submitted payload."
    >
      <:demo>
        <section class="grid gap-5 xl:grid-cols-[minmax(0,1fr)_320px]">
          <form
            id="access-pass-form"
            novalidate
            data-on:submit={event("validate", opts: "{contentType: 'form'}")}
            data-on:reset={event("reset")}
            class="border border-base-300 bg-base-200 p-5"
          >
            <input type="hidden" name="_csrf_token" value={Plug.CSRFProtection.get_csrf_token()} />

            <div class="mb-6 flex items-start justify-between gap-4">
              <div>
                <p class="font-mono text-xs tracking-wide text-base-content/65 uppercase">
                  Form surface
                </p>
                <h2 class="mt-2 text-2xl font-semibold text-base-content">Create an access pass</h2>
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
                hint="Company addresses only — try ada@example.com."
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
                class="inline-flex items-center gap-2 rounded-md border border-primary bg-primary px-4 py-2.5 text-sm font-medium text-primary-content transition hover:bg-primary/90 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary"
              >
                <.icon name="hero-check-micro" class="size-4" /> Validate
              </button>
              <button
                id="access-pass-reset"
                type="reset"
                class="inline-flex items-center gap-2 rounded-md border border-base-300 px-4 py-2.5 text-sm font-medium text-base-content/80 transition hover:border-base-content/40 hover:bg-base-100 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary"
              >
                <.icon name="hero-arrow-path-micro" class="size-4" /> Reset
              </button>
            </div>

            <.validation_panel validation={@validation} intent={@intent} />
          </form>

          <.payload_panel submitted={@submitted} />
        </section>
      </:demo>

      <:how_it_works>
        <.key_points items={[
          "novalidate keeps the browser from intercepting the demo.",
          "contentType: 'form' sends form fields instead of Datastar signals.",
          "The inputs keep their values while server-owned feedback is patched.",
          "patch/3 updates status, field errors, summary, and payload fragments."
        ]} />

        <.prose>
          The form is a real <code class="font-mono text-sm">&lt;form&gt;</code>: Datastar posts it
          with <code class="font-mono text-sm">contentType: 'form'</code>, so the server receives
          ordinary form fields rather than signals. Validation runs server-side and the response
          patches six separate fragments — the status badge, three field-feedback spans, the
          validation panel and the payload panel — leaving the inputs themselves untouched. That is
          why what you typed survives the round trip.
        </.prose>

        <div class="mt-6">
          <.code_block
            language={@snippet.wiring_language}
            label={@snippet.source}
            code={@snippet.wiring}
          />
        </div>
      </:how_it_works>

      <:comparison>
        <.prose>
          Both sides validate the same three fields with the same rules, and both
          keep what you typed while showing server-owned feedback.
        </.prose>

        <.compare>
          <:dstar>
            <.code_block
              language={@snippet.wiring_language}
              label={@snippet.source}
              code={@snippet.wiring}
            />
          </:dstar>

          <:liveview>
            <.code_block language="elixir" label="illustrative" code={@snippet.liveview} />
          </:liveview>

          <:note><.rich_text text={@snippet.note} /></:note>
        </.compare>
      </:comparison>
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
      hint: "Company addresses only — try ada@example.com.",
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
      hint: "Company addresses only — try ada@example.com.",
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
      <span class="mb-2 block text-sm font-medium text-base-content/80">{@label}</span>
      <input
        id={@input_id}
        type={@type}
        name={@name}
        autocomplete={@autocomplete}
        placeholder={@placeholder}
        aria-describedby={@feedback_id}
        class="w-full rounded-md border border-base-300 bg-base-100 px-3 py-3 text-base text-base-content transition placeholder:text-base-content/65 focus:border-primary focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary"
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

  # Hue is available here because the light theme overrides daisyUI's semantic
  # tokens with darker variants (error #b91c1c is 6.47:1 on white; dark keeps
  # daisyUI's #ff627d at 6.81:1 on #0c0c0c). Colour is never the only carrier:
  # rejected is also `font-medium`, and the message text itself differs per
  # state ("Company email accepted" vs "Use an @example.com email").
  def field_feedback(assigns) do
    ~H"""
    <span
      id={"access-pass-#{@name}-feedback"}
      class={[
        "mt-2 block text-sm transition",
        @intent == "idle" && "text-base-content/65",
        @intent != "idle" && @field.valid && "text-success",
        @intent == "rejected" && !@field.valid && "font-medium text-error"
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
        "inline-flex items-center px-2 py-0.5 font-mono text-xs",
        @intent == "accepted" && "bg-primary text-primary-content",
        @intent == "rejected" && "bg-error/20 text-base-content",
        @intent == "idle" && "bg-base-300 text-base-content/70"
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
    <aside id="form-payload" class="border border-base-300 bg-base-100 p-4">
      <p class="font-mono text-xs tracking-wide text-base-content/65 uppercase">
        Submitted form data
      </p>
      <div :if={@submitted?} class="mt-4 space-y-3 text-sm text-base-content/80">
        <div
          :for={name <- ~w(email first_name last_name)}
          class="flex items-center justify-between gap-3"
        >
          <span>{name}</span>
          <code class="truncate bg-base-200 px-2 py-1 font-mono text-base-content">
            {Map.get(@submitted, name, "")}
          </code>
        </div>
      </div>
      <p :if={!@submitted?} class="mt-4 text-sm leading-6 text-base-content/70">
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
    <div id="validation-panel" class="mt-6 border border-base-300 bg-base-100 p-4">
      <div class="flex items-center justify-between gap-4">
        <p class="text-sm font-semibold text-base-content">
          {validation_title(@intent, @ready?)}
        </p>
        <span class={[
          "inline-flex items-center px-2 py-0.5 font-mono text-xs",
          @intent == "accepted" && "bg-primary text-primary-content",
          @intent == "idle" && "bg-base-300 text-base-content/70",
          @intent == "rejected" && "bg-error/20 text-base-content"
        ]}>
          {validation_count(@intent, @validation)}
        </span>
      </div>
      <div class="mt-4 grid gap-2 text-sm text-base-content/70 sm:grid-cols-3">
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
      "border px-3 py-2 text-base-content",
      @field.valid && @intent != "idle" && "border-success/40 bg-success/10",
      !@field.valid && @intent == "rejected" && "border-error/40 bg-error/10",
      (@intent == "idle" || (!@field.valid && @intent != "rejected")) &&
        "border-base-300 bg-base-200"
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
