defmodule Swoosh.Adapters.XML.HelpersTest do
  use ExUnit.Case, async: true
  alias Swoosh.Adapters.XML.Helpers, as: XMLHelper

  setup_all do
    xml_string = """
    <xml>
        <test>Test Text</test>
        <test>Test 2 Text</test>
        <test2>
            <inside></inside>
            <inside>test 2</inside>
        </test2>
    </xml>
    """

    {:ok, xml_string: xml_string}
  end

  test "first_text returns the text of the first xml node found", %{xml_string: xml_string} do
    text =
      xml_string
      |> XMLHelper.parse
      |> XMLHelper.first_text("//test")

    assert text == "Test Text"
  end

  test "first_text returns the a blank on first xml found where empty", %{xml_string: xml_string} do
    text =
      xml_string
      |> XMLHelper.parse
      |> XMLHelper.first_text("//inside")

    assert text == ""
  end

  test "first returns the first xml node found and prints text", %{xml_string: xml_string} do
    text =
      xml_string
      |> XMLHelper.parse
      |> XMLHelper.first("//test")
      |> XMLHelper.text

    assert text == "Test Text"
  end

  test "text prints blank on empty node", %{xml_string: xml_string} do
    text =
      xml_string
      |> XMLHelper.parse
      |> XMLHelper.first("//test2/inside")
      |> XMLHelper.text

    assert text == ""
  end
end
