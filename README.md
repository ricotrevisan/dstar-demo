# Dstar demo

Simple and reactive Phoenix pages.

[Dstar](https://hexdocs.pm/dstar) renders Phoenix pages over
[Datastar](https://data-star.dev). A click is an ordinary request: it goes
through your router, runs a handler, and comes back as HTML patches for
whatever changed. Nothing stays open between clicks. When a page needs live
updates, one attribute opens a stream.

This repo is the site at https://dstar.nocode-to-knowcode.com:

- `/`: an inbox built with LiveView 1.8 and with Dstar, arrow by arrow
- `/explained/lab`: the same inbox in six tabs, to break on purpose
- `/showcase`: small examples of each Dstar feature
- `bench/`: a reproducible LiveView vs Dstar benchmark

Library: [github.com/ricotrevisan/dstar](https://github.com/ricotrevisan/dstar).
Found a rough edge? [Open an issue](https://github.com/ricotrevisan/dstar-demo/issues).

## Run it

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
