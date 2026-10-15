defmodule DstarDemoWeb.HomeCodeTest do
  @moduledoc """
  The stage-by-stage diffs and the finished files are written by hand, in
  one module. Stacked, the stages must build the finished files: every line
  a stage adds is in the finished file, and every line it removes is gone.
  """
  use ExUnit.Case, async: true

  alias DstarDemoWeb.HomeCode

  # Lines a later stage removes, so an earlier stage may add them.
  defp removed_after(n, lane) do
    for later <- (n + 1)..6//1,
        {_file, diff} <- HomeCode.stage(later, lane),
        "-" <> line <- String.split(diff, "\n"),
        into: MapSet.new(),
        do: String.trim(line)
  end

  defp lines(text) do
    text |> String.split("\n") |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == ""))
  end

  for lane <- [:lv, :ds], n <- 1..6 do
    @lane lane
    @n n

    test "stage #{n} (#{lane}) only adds lines the finished files have, and only removes lines they don't" do
      finished = Map.new(HomeCode.files(@lane), fn {file, code} -> {file, lines(code)} end)
      replaced = removed_after(@n, @lane)

      for {file, diff} <- HomeCode.stage(@n, @lane) do
        assert Map.has_key?(finished, file), "stage #{@n} touches #{file}, which isn't shown"

        for line <- String.split(diff, "\n") do
          case line do
            "+" <> added ->
              added = String.trim(added)

              assert added == "" or added in finished[file] or added in replaced,
                     "stage #{@n} adds #{inspect(added)} to #{file}, but the finished file lacks it and no later stage removes it"

            "-" <> removed ->
              refute String.trim(removed) in finished[file],
                     "stage #{@n} removes #{inspect(removed)} from #{file}, but it's still there"

            _context ->
              :ok
          end
        end
      end
    end
  end

  test "every finished file is touched by some stage" do
    for lane <- [:lv, :ds] do
      touched = for n <- 1..6, {file, _} <- HomeCode.stage(n, lane), into: MapSet.new(), do: file

      for {file, _code} <- HomeCode.files(lane) do
        assert file in touched, "#{lane}: no stage introduces #{file}"
      end
    end
  end

  test "a deploy needs no code in either model" do
    assert HomeCode.stage(6, :lv) == []
    assert HomeCode.stage(6, :ds) == []
  end
end
