defmodule DstarDemoWeb.ErrorJSONTest do
  use DstarDemoWeb.ConnCase, async: true

  test "renders 404" do
    assert DstarDemoWeb.ErrorJSON.render("404.json", %{}) == %{errors: %{detail: "Not Found"}}
  end

  test "renders 500" do
    assert DstarDemoWeb.ErrorJSON.render("500.json", %{}) ==
             %{errors: %{detail: "Internal Server Error"}}
  end
end
