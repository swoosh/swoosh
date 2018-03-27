defmodule Swoosh.Adapters.XML.Helpers do
  @moduledoc false
  require Record

  Record.defrecord(:xmlText, Record.extract(:xmlText, from_lib: "xmerl/include/xmerl.hrl"))

  @doc false
  def parse(xml_string, options \\ []) do
    {node, _} =
      xml_string
      |> :binary.bin_to_list()
      |> :xmerl_scan.string(Keyword.merge([quiet: true], options))

    node
  end

  @doc """
    returns the text value of the first found node
  """
  def first_text(node, path) do
    node
    |> first(path)
    |> text
  end

  @doc false
  def first(node, path) do
    path
    |> to_charlist
    |> :xmerl_xpath.string(node)
    |> List.first()
  end

  @doc false
  def text(node) do
    "./text()"
    |> to_charlist
    |> :xmerl_xpath.string(node)
    |> extract_text
  end

  defp extract_text([xmlText(value: value)]), do: List.to_string(value)
  defp extract_text(_), do: ""
end
