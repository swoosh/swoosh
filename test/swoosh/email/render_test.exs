defmodule Swoosh.Email.RenderTest do
  use ExUnit.Case, async: true

  alias Swoosh.Email.Render

  test "preserves the local part while encoding an international domain" do
    assert Render.render_recipient({"José", "δοκιμή@bücher.example"}) ==
             ~s("José" <δοκιμή@xn--bcher-kva.example>)
  end

  test "encodes each recipient's domain in a recipient list" do
    recipients = [
      {nil, "reader@example.com"},
      {"", "reader@mañana.example"},
      {"Reader", "reader@例え.テスト"}
    ]

    assert Render.render_recipient(recipients) ==
             ~s(reader@example.com, reader@xn--maana-pta.example, "Reader" <reader@xn--r8jz45g.xn--zckzah>)
  end

  test "preserves an international domain's trailing root label" do
    assert Render.render_recipient({nil, "reader@bücher.example."}) ==
             "reader@xn--bcher-kva.example."
  end
end
