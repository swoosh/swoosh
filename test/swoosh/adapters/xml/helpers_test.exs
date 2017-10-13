defmodule Swoosh.Adapters.XML.HelpersTest do
  use ExUnit.Case, async: true
  alias Swoosh.Adapters.XML.Helpers, as: XmlHelper

  setup do
    xml_string ="""
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

  test "parse returns xmlnode ", %{xml_string: xml_string} do
    assert XmlHelper.parse(xml_string) == %{}
  end

  test "first returns the first xml node found", %{xml_string: xml_string} do
    xml_node = XmlHelper.parse(xml_string)
    assert XmlHelper.first(xml_node, "//test") == %{}
  end

  test "text returns the text value of the xml node", %{xml_string: xml_string} do
    xml_node =
      XmlHelper.parse(xml_string)
      |> XmlHelper.first("//test")

    assert XmlHelper.text(xml_node) == "Test Text"
  end
end
