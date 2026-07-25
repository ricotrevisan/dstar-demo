# DstarDemo

To start your Phoenix server:

* Run `mix setup` to install dependencies, start Postgres, and create the database
* Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

## Database

The Live Collections demo is backed by Postgres; every other demo is
in-memory. `mix setup` brings the database up via Docker, so the only
prerequisite is a running Docker daemon.

```bash
mix db.up      # docker compose up -d --wait
mix db.down    # stop it again
mix ecto.reset # drop, create, migrate
```

It listens on **5433**, not the default 5432, so it stays out of the way of
any system Postgres you already run. Override with `PGHOST`, `PGPORT`,
`PGUSER`, `PGPASSWORD` to point at your own instance instead.

Postgres connects lazily, so with the database down the app still boots and
every non-database demo still works — you just get `:econnrefused` repeating
in the log until it comes back. `mix test` does need it, since the suite runs
inside `Ecto.Adapters.SQL.Sandbox`.

## Local HTTPS

This project uses local `mkcert` certificates from `priv/cert/` when they exist. HTTPS is served on one port higher than `PORT`:

* `PORT=4000` -> HTTP on `http://localhost:4000`, HTTPS on `https://localhost:4001`
* `PORT=4100 mix phx.server` -> HTTP on `4100`, HTTPS on `4101`

To regenerate the local certificate:

```bash
mkcert -install
mkdir -p priv/cert
mkcert \
  -key-file priv/cert/localhost-key.pem \
  -cert-file priv/cert/localhost.pem \
  localhost 127.0.0.1 ::1
```

Set `HTTPS=false` to start without HTTPS. The certificate files are ignored by git.

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## Learn more

* Official website: https://www.phoenixframework.org/
* Guides: https://hexdocs.pm/phoenix/overview.html
* Docs: https://hexdocs.pm/phoenix
* Forum: https://elixirforum.com/c/phoenix-forum
* Source: https://github.com/phoenixframework/phoenix
