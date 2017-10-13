defmodule Swoosh.Adapters.XML.Helpers do
  require Record

  Record.defrecord :xmlText, Record.extract(:xmlText, from_lib: "xmerl/include/xmerl.hrl")

  def parse(xml_string, options \\ [quiet: true]) do
    {node, _} =
      xml_string
      |> :binary.bin_to_list
      |> :xmerl_scan.string(options)

    node
  end

  def first(node, path) do
    :xmerl_xpath.string(to_char_list(path), node)
    |> extract_first
  end

  defp extract_first([head | _]), do: head

  def text(node) do
    :xmerl_xpath.string(to_char_list("./text()"), node)
    |> extract_text
  end

  defp extract_text([xmlText(value: value)]), do: List.to_string(value)
  defp extract_text(_), do: ""
end
