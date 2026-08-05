# DstarDemo

To start your Phoenix server:

* Run `mix setup` to install dependencies and create the database
* Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

## Database

The Live Collections demo is backed by Postgres; every other demo is
in-memory. It expects a Postgres on `localhost:5432` with
`postgres/postgres` credentials. Override with `PGHOST`, `PGPORT`,
`PGUSER`, `PGPASSWORD` to point at your own instance instead.

```bash
mix ecto.reset # drop, create, migrate
```

Postgres connects lazily, so with the database down the app still boots and
every non-database demo still works — you just get `:econnrefused` repeating
in the log until it comes back. `mix test` does need it, since the suite runs
inside `Ecto.Adapters.SQL.Sandbox`.

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## Learn more

* Official website: https://www.phoenixframework.org/
* Guides: https://hexdocs.pm/phoenix/overview.html
* Docs: https://hexdocs.pm/phoenix
* Forum: https://elixirforum.com/c/phoenix-forum
* Source: https://github.com/phoenixframework/phoenix
