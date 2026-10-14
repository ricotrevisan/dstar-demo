defmodule Mix.Tasks.Bench.Report do
  @shortdoc "Summarizes a results directory into SUMMARY.md and summary.json"
  @moduledoc """
  Reads every `<model>-<repeat>.json` in a results directory, takes the
  median of each metric across repeats, and writes `SUMMARY.md` (for
  people) and `summary.json` (for the lab page).

      MIX_ENV=prod mix bench.report results/2026-10-14-1000tabs
  """
  use Mix.Task

  @models [
    {"liveview", "LiveView"},
    {"dstar", "Dstar, with stream"},
    {"dstar_nostream", "Dstar, no stream"}
  ]

  # {section, label, path into a result, unit}
  @rows [
    {"Holding tabs open", "Server memory per open tab", ["idle", "memory_bytes_per_tab"], :kb},
    {"Holding tabs open", "Server processes per open tab", ["idle", "processes_per_tab"], :n},
    {"Opening a tab", "Server CPU per tab opened", ["open", "server_cpu_ms_per_tab"], :ms},
    {"Opening a tab", "HTML per page load", ["open", "html_bytes_per_tab"], :kb},
    {"One click", "Round trip for the clicking tab, p50",
     ["clicks", "clicker_round_trip_ms", "p50"], :ms},
    {"One click", "Round trip for the clicking tab, p95",
     ["clicks", "clicker_round_trip_ms", "p95"], :ms},
    {"One click", "Bytes back to the clicking tab", ["clicks", "clicker_response_bytes"], :bytes},
    {"One click", "Until every open tab is updated, p50",
     ["clicks", "all_tabs_updated_ms", "p50"], :ms},
    {"One click", "Until every open tab is updated, p95",
     ["clicks", "all_tabs_updated_ms", "p95"], :ms},
    {"One click", "Bytes pushed to each other tab", ["clicks", "push_bytes_per_tab"], :bytes},
    {"One click", "Server CPU per click, fan-out included", ["clicks", "server_cpu_ms_per_click"],
     :ms},
    {"A deploy", "Connections dropped", ["deploy", "dropped"], :n},
    {"A deploy", "Until every tab is back", ["deploy", "all_back_ms"], :ms},
    {"A deploy", "Server CPU for the reconnect storm", ["deploy", "server_cpu_ms"], :ms},
    {"A deploy", "mount runs during the storm", ["deploy", "callbacks", "lv_mount_socket"],
     :mounts},
    {"A deploy", "handle_connect runs during the storm", ["deploy", "callbacks", "ds_connect"],
     :n}
  ]

  @impl true
  def run([dir]) do
    results =
      dir
      |> Path.join("*.json")
      |> Path.wildcard()
      |> Enum.reject(&String.ends_with?(&1, "summary.json"))
      |> Enum.map(&(&1 |> File.read!() |> Jason.decode!()))

    if results == [], do: Mix.raise("no results in #{dir}")

    by_model = Enum.group_by(results, & &1["model"])
    sample = hd(results)

    medians =
      for {model, _label} <- @models, runs = by_model[model], runs != nil, into: %{} do
        {model,
         Map.new(@rows, fn {_s, label, path, _u} ->
           {label, runs |> Enum.map(&get_in(&1, path)) |> median()}
         end)}
      end

    summary = %{
      params: sample["params"],
      env: sample["env"],
      repeats: by_model |> Map.values() |> Enum.map(&length/1) |> Enum.min(),
      models: medians
    }

    File.write!(Path.join(dir, "summary.json"), Jason.encode!(summary, pretty: true) <> "\n")
    File.write!(Path.join(dir, "SUMMARY.md"), markdown(summary))
    Mix.shell().info("wrote #{Path.join(dir, "SUMMARY.md")}")
  end

  def run(_), do: Mix.raise("usage: mix bench.report <results-dir>")

  defp markdown(summary) do
    env = summary.env
    params = summary.params
    present = Enum.filter(@models, fn {m, _} -> Map.has_key?(summary.models, m) end)

    header =
      "| | " <>
        Enum.map_join(present, " | ", &elem(&1, 1)) <>
        " |\n" <>
        "| --- |" <> String.duplicate(" ---: |", length(present)) <> "\n"

    sections =
      @rows
      |> Enum.chunk_by(&elem(&1, 0))
      |> Enum.map_join("\n", fn [{section, _, _, _} | _] = rows ->
        "### #{section}\n\n" <>
          header <>
          Enum.map_join(rows, "", fn {_s, label, _path, unit} ->
            "| #{label} | " <>
              Enum.map_join(present, " | ", fn {m, _} ->
                format(summary.models[m][label], unit)
              end) <>
              " |\n"
          end)
      end)

    """
    # Benchmark: one inbox, LiveView vs Dstar

    #{params["tabs"]} open tabs · #{params["clicks"]} clicks · median of #{summary.repeats} runs per model

    #{sections}
    ## Environment

    - CPU: #{env["cpu"]} (#{env["logical_processors"]} logical processors, #{env["schedulers"]} schedulers)
    - OS: #{env["os"]}
    - Erlang/OTP #{env["otp_release"]} (ERTS #{env["erts_version"]}), Elixir #{env["elixir"]}
    - phoenix #{env["deps"]["phoenix"]}, phoenix_live_view #{env["deps"]["phoenix_live_view"]}, bandit #{env["deps"]["bandit"]}, dstar #{env["deps"]["dstar"]}
    - Run at #{env["run_at"]} (UTC). Server and load generator on the same machine, over loopback.

    See `bench/README.md` for what each number means and how to reproduce it.
    """
  end

  defp format(nil, _), do: "–"
  # Below zero is measurement noise around "nothing retained".
  defp format(v, :kb) when v < 0, do: "≈ 0 KB"
  defp format(v, :kb), do: "#{Float.round(v / 1024, 1)} KB"
  defp format(v, :ms), do: "#{Float.round(v * 1.0, 2)} ms"
  defp format(v, :bytes), do: "#{round(v)} B"
  defp format(v, _), do: "#{v}"

  defp median(values) do
    case values |> Enum.reject(&is_nil/1) |> Enum.sort() do
      [] -> nil
      sorted -> Enum.at(sorted, div(length(sorted), 2))
    end
  end
end
