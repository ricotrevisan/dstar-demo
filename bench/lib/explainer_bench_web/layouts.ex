defmodule ExplainerBenchWeb.Layouts do
  @moduledoc "The one root layout both models render inside."
  use Phoenix.Component

  import Phoenix.Controller, only: [get_csrf_token: 0]

  def root(assigns) do
    ~H"""
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta charset="utf-8" />
        <meta name="csrf-token" content={get_csrf_token()} />
        <title>Inbox</title>
      </head>
      <body data-signals={Jason.encode!(%{csrf: get_csrf_token()})}>
        {@inner_content}
      </body>
    </html>
    """
  end
end
