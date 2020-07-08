defmodule Plug.Parsers.RFC822 do
  @moduledoc """
  Local fork of https://github.com/DefactoSoftware/xml_parser
  with some mods
  """
  @behaviour Plug.Parsers

  def init(opts) do
    {body_reader, opts} =
      Keyword.pop(opts, :body_reader, {Plug.Conn, :read_body, []})

    {body_reader, nil, opts}
  end

  def parse(conn, _, "rfc822", _headers, {{mod, fun, args}, decoder, opts}) do
    mod
    |> apply(fun, [conn, opts | args])
    |> decode(decoder)
  end

  def parse(conn, _type, _subtype, _headers, _opts) do
    {:next, conn}
  end

  defp decode({:ok, body, conn}, nil) do
    parsed = %Mail.Message{} = Mail.Parsers.RFC2822.parse(body)
    {:ok, parsed, conn}
  end
end
