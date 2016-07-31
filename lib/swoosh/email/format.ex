defmodule Swoosh.Email.Format do
  @moduledoc false

  def format_recipient(nil), do: ""
  def format_recipient({nil, address}), do: address
  def format_recipient({"", address}), do: address
  def format_recipient({name, address}), do: "#{name} <#{address}>"
  def format_recipient([]), do: ""
  def format_recipient(list) when is_list(list) do
    list
    |> Enum.map(&format_recipient/1)
    |> Enum.join(", ")
  end
end
