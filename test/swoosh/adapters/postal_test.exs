defmodule Swoosh.Adapters.PostalTest do
  use Swoosh.AdapterCase, async: true

  import Swoosh.Email
  alias Swoosh.Adapters.Postal

  @success_response """
  {
    "status": "success",
    "time": 0.123,
    "flags": {},
    "data": {
      "message_id": "d7eabab3-5936-42ff-a419-711cc76f23c8@test.postalserver.io"
    }
  }
  """

  setup do
    bypass = Bypass.open()
    config = [api_key: "123", base_url: "http://localhost:#{bypass.port}"]

    valid_email =
      new()
      |> from("tony.stark@example.com")
      |> to({"Steve Rogers", "steve.rogers@example.com"})
      |> subject("Hello, Avengers!")
      |> html_body("<h1>Hello</h1>")
      |> text_body("Hello")

    {:ok, bypass: bypass, config: config, valid_email: valid_email}
  end

  test "successful delivery returns :ok", %{
    bypass: bypass,
    config: config,
    valid_email: email
  } do
    Bypass.expect(bypass, fn conn ->
      conn = parse(conn)

      body_params = %{
        "from" => "tony.stark@example.com",
        "to" => [~s("Steve Rogers" <steve.rogers@example.com>)],
        "subject" => "Hello, Avengers!",
        "html_body" => "<h1>Hello</h1>",
        "plain_body" => "Hello"
      }

      assert body_params == conn.body_params
      assert "/api/v1/send/message" == conn.request_path
      assert "POST" == conn.method
      assert {"content-type", "application/json"} in conn.req_headers

      conn
      |> Plug.Conn.put_resp_header("content-type", "application/json")
      |> Plug.Conn.resp(200, @success_response)
    end)

    assert Postal.deliver(email, config) ==
             {:ok, %{id: "d7eabab3-5936-42ff-a419-711cc76f23c8@test.postalserver.io"}}
  end

  test "deliver/1 with all fields returns :ok", %{bypass: bypass, config: config} do
    email =
      new()
      |> from({"T Stark", "tony.stark@example.com"})
      |> to({"Steve Rogers", "steve.rogers@example.com"})
      |> to("wasp.avengers@example.com")
      |> reply_to("office.avengers@example.com")
      |> cc({"Bruce Banner", "hulk.smash@example.com"})
      |> cc("thor.odinson@example.com")
      |> bcc({"Clinton Francis Barton", "hawk.eye@example.com"})
      |> bcc("beast.avengers@example.com")
      |> subject("Hello, Avengers!")
      |> html_body("<h1>Hello</h1>")
      |> text_body("Hello")
      |> header("x-custom-header", "hello")
      |> attachment("test/support/attachment.txt")
      |> attachment(
        Swoosh.Attachment.new(
          {:data, "text stuff"},
          filename: "foo.txt",
          content_type: "text/plain"
        )
      )
      |> put_provider_option(:tag, "Avengers")
      |> put_provider_option(:bounce, false)

    Bypass.expect(bypass, fn conn ->
      conn = parse(conn)

      body_params = %{
        "subject" => "Hello, Avengers!",
        "to" => [
          ~s(wasp.avengers@example.com),
          ~s("Steve Rogers" <steve.rogers@example.com>)
        ],
        "bcc" => [
          ~s(beast.avengers@example.com),
          ~s("Clinton Francis Barton" <hawk.eye@example.com>)
        ],
        "cc" => [
          ~s(thor.odinson@example.com),
          ~s("Bruce Banner" <hulk.smash@example.com>)
        ],
        "reply_to" => "office.avengers@example.com",
        "from" => ~s("T Stark" <tony.stark@example.com>),
        "plain_body" => "Hello",
        "html_body" => "<h1>Hello</h1>",
        "bounce" => false,
        "headers" => %{"x-custom-header" => "hello"},
        "tag" => "Avengers",
        "attachments" => [
          %{
            "name" => "foo.txt",
            "content_type" => "text/plain",
            "data" => Base.encode64("text stuff")
          },
          %{
            "name" => "attachment.txt",
            "content_type" => "text/plain",
            "data" => Base.encode64(File.read!("test/support/attachment.txt"))
          }
        ]
      }

      assert body_params == conn.body_params
      assert "/api/v1/send/message" == conn.request_path
      assert "POST" == conn.method
      assert {"content-type", "application/json"} in conn.req_headers

      conn
      |> Plug.Conn.put_resp_header("content-type", "application/json")
      |> Plug.Conn.resp(200, @success_response)
    end)

    assert Postal.deliver(email, config) ==
             {:ok, %{id: "d7eabab3-5936-42ff-a419-711cc76f23c8@test.postalserver.io"}}
  end

  test "deliver/1 fails when API returns ok response with non-success status", %{
    bypass: bypass,
    config: config,
    valid_email: email
  } do
    Bypass.expect(bypass, fn conn ->
      conn = parse(conn)

      response = """
      {
      "status": "error",
      "time": null,
      "flags": {},
      "data": {
        "code": "AccessDenied",
        "message": "Must be authenticated as a server.",
        "action": "message",
        "controller": "send"
      }
      }
      """

      conn
      |> Plug.Conn.put_resp_header("content-type", "application/json")
      |> Plug.Conn.resp(200, response)
    end)

    assert Postal.deliver(email, config) ==
             {:error, {"AccessDenied", "Must be authenticated as a server."}}
  end

  test "deliver/1 fails when API returns non-ok response", %{
    bypass: bypass,
    config: config,
    valid_email: email
  } do
    Bypass.expect(bypass, fn conn ->
      conn = parse(conn)
      Plug.Conn.resp(conn, 500, "")
    end)

    assert Postal.deliver(email, config) == {:error, {500, ""}}
  end
end
