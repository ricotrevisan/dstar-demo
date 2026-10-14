defmodule ExplainerBench.MixProject do
  use Mix.Project

  # Versions are pinned to what dstar-demo ships, so the numbers describe
  # the same stack the explainer pages run on.
  def project do
    [
      app: :explainer_bench,
      version: "0.1.0",
      elixir: "~> 1.15",
      start_permanent: false,
      deps: deps()
    ]
  end

  def application do
    [mod: {ExplainerBench.Application, []}, extra_applications: [:logger]]
  end

  defp deps do
    [
      {:phoenix, "1.8.11"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_view, "1.1.33"},
      {:bandit, "1.12.4"},
      {:jason, "~> 1.2"},
      {:dstar, github: "ricotrevisan/dstar", ref: "91db2de4882669a85492aeef2fcaee1e5382d489"},
      # Load generator only.
      {:mint, "~> 1.6"},
      {:mint_web_socket, "~> 1.0"}
    ]
  end
end
