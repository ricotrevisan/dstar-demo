defmodule DstarDemo.DataCase do
  @moduledoc """
  Test case for tests that talk to the database.

  Each test runs inside a transaction that is rolled back afterwards, so
  tests never see each other's rows. `use DstarDemo.DataCase, async: true`
  is safe; without `async` the sandbox runs in shared mode so processes
  spawned by the test (stream tasks, for instance) can reach the same
  connection.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import DstarDemo.DataCase
    end
  end

  setup tags do
    setup_sandbox(tags)
    :ok
  end

  @doc """
  Checks out a sandboxed connection for the test, shared with any process
  the test spawns unless the test is async.
  """
  def setup_sandbox(tags) do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(DstarDemo.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
  end
end
