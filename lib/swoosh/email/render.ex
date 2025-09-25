defmodule Swoosh.Email.Render do
  @moduledoc false

  def render_recipient(nil), do: ""
  def render_recipient({nil, address}), do: puny_encode(address)
  def render_recipient({"", address}), do: puny_encode(address)
  def render_recipient([]), do: ""
  def render_recipient("TEMPLATE"), do: "TEMPLATE"

  def render_recipient({name, address}) do
    name =
      name
      |> String.replace("\\", "\\\\")
      |> String.replace("\"", "\\\"")

    ~s("#{name}" <#{puny_encode(address)}>)
  end

  def render_recipient(list) when is_list(list) do
    list
    |> Enum.map_join(", ", &render_recipient/1)
  end

  defp puny_encode(email) do
    case String.split(email, "@") do
      [local, domain] ->
        encoded_domain = :idna.utf8_to_ascii(domain)
        Enum.join([local, encoded_domain], "@")

      _ ->
        email
    end
  end
end
