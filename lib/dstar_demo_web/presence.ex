defmodule DstarDemoWeb.Presence do
  @moduledoc false

  use Phoenix.Presence,
    otp_app: :dstar_demo,
    pubsub_server: DstarDemo.PubSub
end
