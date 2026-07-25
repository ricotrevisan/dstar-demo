defmodule DstarDemo.Repo do
  use Ecto.Repo,
    otp_app: :dstar_demo,
    adapter: Ecto.Adapters.Postgres
end
