defmodule DstarDemo.ChaosLabTest do
  use ExUnit.Case, async: true

  alias DstarDemo.ChaosLab

  test "opening six tabs: LiveView mounts twice per tab, Dstar once, and only LiveView holds copies" do
    lab = ChaosLab.new()

    assert lab.lv.mounts == 12
    assert lab.ds.mounts == 6
    assert lab.lv.copies == 6
    assert lab.ds.copies == 0
  end

  test "deploy remounts every LiveView tab and re-authorizes every Dstar stream without mounting" do
    lab = ChaosLab.new()
    after_deploy = ChaosLab.apply_action(lab, "deploy")

    assert after_deploy.lv.mounts == lab.lv.mounts + 6
    assert after_deploy.ds.mounts == lab.ds.mounts
    assert after_deploy.ds.auth == lab.ds.auth + 6
  end

  test "a click from the tunnel is lost in LiveView and retried by Dstar on the way out" do
    lab = ChaosLab.new() |> ChaosLab.apply_action("tunnel")
    tunnel_id = ChaosLab.tunnel_tab()

    # Round-robin until the tunnel tab is the one clicking.
    lab =
      Enum.reduce(1..(tunnel_id - 1), lab, fn _, acc -> ChaosLab.apply_action(acc, "click") end)

    db_before = lab.ds.db
    lab = ChaosLab.apply_action(lab, "click")

    assert Enum.find(lab.tabs, &(&1.id == tunnel_id)).pending == 1
    assert lab.ds.db == db_before

    lab = ChaosLab.apply_action(lab, "tunnel")
    assert lab.ds.db == db_before - 1
    assert Enum.find(lab.tabs, &(&1.id == tunnel_id)).pending == 0
  end

  test "revoking Ada logs out both of her tabs in both worlds and is idempotent" do
    lab = ChaosLab.new() |> ChaosLab.apply_action("revoke")

    for tab <- lab.tabs, tab.user == "Ada" do
      assert tab.lv == :out
      assert tab.ds == :out
    end

    assert lab.lv.copies == 4
    assert ChaosLab.apply_action(lab, "revoke") == lab
  end
end
