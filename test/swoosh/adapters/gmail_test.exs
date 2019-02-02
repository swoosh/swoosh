defmodule Swoosh.Adapters.GmailTest do
  use Swoosh.AdapterCase, async: true

  import Swoosh.Email
  alias Swoosh.Adapters.Gmail

  @success_response """
    {
      "id": "234jkasdfl",
      "threadId": "12312adfsx",
      "labelIds": ["SENT"]
    }
  """

  setup do
    bypass = Bypass.open()
    config = [base_url: "http://localhost:#{bypass.port}", access_token: "test_token"]

    valid_email =
      new()
      |> from("steve.rogers@example.com")
      |> to("tony.stark@example.com")
      |> subject("Hello, Avengers!")
      |> html_body("<h1>Hello</h1>")

    {:ok, bypass: bypass, valid_email: valid_email, config: config}
  end

  test "a sent email results in :ok", %{bypass: bypass, config: config, valid_email: email} do
    Bypass.expect(bypass, fn conn ->
      conn = parse(conn)
      boundary = get_boundary(conn.body_params)

      body_params = ~s"""
      To: "" <tony.stark@example.com>\r
      Subject: Hello, Avengers!\r
      Mime-Version: 1.0\r
      From: "" <steve.rogers@example.com>\r
      Content-Type: multipart/alternative; boundary="#{boundary}"\r
      \r
      --#{boundary}\r
      Content-Type: text/html\r
      Content-Transfer-Encoding: quoted-printable\r
      \r
      <h1>Hello</h1>\r
      --#{boundary}--\
      """ |> Base.url_encode64()

      assert Map.put(%{}, "raw", body_params) == conn.body_params
      assert "/users/me/messages/send" == conn.request_path
      assert "POST" == conn.method

      Plug.Conn.resp(conn, 200, @success_response)
    end)

    assert Gmail.deliver(email, config) ==
             {:ok, %{id: "234jkasdfl", thread_id: "12312adfsx", labels: ["SENT"]}}
  end

  defp get_boundary(%{"raw" => raw} = _body) do
    raw
    |> Base.url_decode64!()
    |> Mail.Parsers.RFC2822.parse()
    |> Mail.Message.get_boundary()
  end
end
