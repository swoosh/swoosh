defmodule Swoosh.Email.Render do
  @moduledoc false

  def render_recipient(nil), do: ""
  def render_recipient({nil, address}), do: address
  def render_recipient({"", address}), do: address
  def render_recipient({name, address}), do: ~s("#{name}" <#{address}>)
  def render_recipient([]), do: ""

  def render_recipient(list) when is_list(list) do
    list
    |> Enum.map_join(", ", &render_recipient/1)
  end
end
