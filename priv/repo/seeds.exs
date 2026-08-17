import Ecto.Query

alias DstarDemo.LiveCollections.Item
alias DstarDemo.Repo

[
  {"Review edge deployment", :queued},
  {"Verify signal contract", :active},
  {"Ship collection nudge", :done}
]
|> Enum.each(fn {title, status} ->
  unless Repo.exists?(from(item in Item, where: item.title == ^title)) do
    %Item{}
    |> Item.changeset(%{title: title, status: status})
    |> Repo.insert!()
  end
end)
