defmodule Swoosh.Adapters.XML.HelpersTest do
  require Record
  use ExUnit.Case, async: true
  alias Swoosh.Adapters.XML.Helpers, as: XmlHelper

  Record.defrecord :xmlElement, Record.extract(:xmlElement, from_lib: "xmerl/include/xmerl.hrl")

  setup do
    xml_string = """
    <xml>
        <test>Test Text</test>
        <test>Test 2 Text</test>
        <test2>
            <inside></inside>
        </test2>
    </xml>
    """

    {:ok, xml_string: xml_string}
  end

  test "first returns the first xml node found and prints text", %{xml_string: xml_string} do
    text =
      XmlHelper.parse(xml_string)
      |> XmlHelper.first("//test")
      |> XmlHelper.text

    assert text == "Test Text"
  end

  test "text prints blank on empty node", %{xml_string: xml_string} do
    text =
      XmlHelper.parse(xml_string)
      |> XmlHelper.first("//test2/inside")
      |> XmlHelper.text

    assert text == ""
  end
end
