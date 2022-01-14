defmodule Swoosh.Adapters.OhMySmtpTest do
  use Swoosh.AdapterCase, async: true

  import Swoosh.Email
  alias Swoosh.Adapters.OhMySmtp

  @success_response '{"id":404021,"status":"queued"}'

  setup do
    bypass = Bypass.open()

    config = [
      endpoint: "http://localhost:#{bypass.port}",
      api_key: "fake"
    ]

    valid_email =
      new()
      |> from("tony.stark@example.com")
      |> to("steve.rogers@example.com")
      |> subject("Hello, Avengers!")
      |> html_body("<h1>Hello</h1>")

    {:ok, bypass: bypass, valid_email: valid_email, config: config}
  end

  test "a sent email results in :ok", %{bypass: bypass, config: config, valid_email: email} do
    Bypass.expect(bypass, fn conn ->
      conn = parse(conn)

      body_params = %{
        "from" => "tony.stark@example.com",
        "to" => "steve.rogers@example.com",
        "htmlbody" => "<h1>Hello</h1>",
        "subject" => "Hello, Avengers!"
      }

      assert body_params == conn.body_params
      assert "POST" == conn.method

      Plug.Conn.resp(conn, 200, @success_response)
    end)

    assert {:ok, Swoosh.json_library().decode!(@success_response)} ==
             OhMySmtp.deliver(email, config)
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

    Bypass.expect(bypass, fn conn ->
      conn = parse(conn)

      body_params = %{
        "from" => "\"T Stark\" <tony.stark@example.com>",
        "to" => "wasp.avengers@example.com, \"Steve Rogers\" <steve.rogers@example.com>",
        "replyto" => "office.avengers@example.com",
        "cc" => "thor.odinson@example.com, \"Bruce Banner\" <hulk.smash@example.com>",
        "bcc" => "beast.avengers@example.com, \"Clinton Francis Barton\" <hawk.eye@example.com>",
        "subject" => "Hello, Avengers!",
        "htmlbody" => "<h1>Hello</h1>",
        "textbody" => "Hello"
      }

      assert body_params == conn.body_params
      assert "POST" == conn.method

      Plug.Conn.resp(conn, 200, @success_response)
    end)

    assert {:ok, Swoosh.json_library().decode!(@success_response)} ==
             OhMySmtp.deliver(email, config)
  end

  test "deliver/1 with an attachment", %{bypass: bypass, config: config} do
    email =
      new()
      |> from({"T Stark", "tony.stark@example.com"})
      |> to({"Steve Rogers", "steve.rogers@example.com"})
      |> subject("Hello, Avengers!")
      |> attachment("test/support/attachment.txt")

    Bypass.expect(bypass, fn conn ->
      conn = parse(conn)

      attachment_content =
        "test/support/attachment.txt"
        |> File.read!()
        |> Base.encode64()

      body_params = %{
        "from" => "\"T Stark\" <tony.stark@example.com>",
        "to" => "\"Steve Rogers\" <steve.rogers@example.com>",
        "subject" => "Hello, Avengers!",
        "attachments" => [
          %{
            "name" => "attachment.txt",
            "content" => attachment_content,
            "content_type" => "text/plain"
          }
        ]
      }

      assert body_params == conn.body_params
      assert "POST" == conn.method

      Plug.Conn.resp(conn, 200, @success_response)
    end)

    assert {:ok, Swoosh.json_library().decode!(@success_response)} ==
             OhMySmtp.deliver(email, config)
  end

  test "deliver/1 with an inline attachment", %{bypass: bypass, config: config} do
    email =
      new()
      |> from({"T Stark", "tony.stark@example.com"})
      |> to({"Steve Rogers", "steve.rogers@example.com"})
      |> subject("Hello, Avengers!")
      |> attachment(Swoosh.Attachment.new("test/support/attachment.txt", type: :inline))

    Bypass.expect(bypass, fn conn ->
      conn = parse(conn)

      attachment_content =
        "test/support/attachment.txt"
        |> File.read!()
        |> Base.encode64()

      body_params = %{
        "from" => "\"T Stark\" <tony.stark@example.com>",
        "to" => "\"Steve Rogers\" <steve.rogers@example.com>",
        "subject" => "Hello, Avengers!",
        "attachments" => [
          %{
            "name" => "attachment.txt",
            "content" => attachment_content,
            "content_type" => "text/plain",
            "cid" => "attachment.txt"
          }
        ]
      }

      assert body_params == conn.body_params
      assert "POST" == conn.method

      Plug.Conn.resp(conn, 200, @success_response)
    end)

    assert {:ok, Swoosh.json_library().decode!(@success_response)} ==
             OhMySmtp.deliver(email, config)
  end

  test "deliver/1 with 4xx response", %{bypass: bypass, config: config, valid_email: email} do
    Bypass.expect(bypass, fn conn ->
      Plug.Conn.resp(conn, 422, "{}")
    end)

    assert {:error, {422, %{}}} = OhMySmtp.deliver(email, config)
  end

  test "deliver/1 with 5xx response", %{bypass: bypass, valid_email: email, config: config} do
    Bypass.expect(bypass, fn conn ->
      Plug.Conn.resp(conn, 500, "{}")
    end)

    assert {:error, {500, %{}}} = OhMySmtp.deliver(email, config)
  end

  test "validate_config/1 with valid config", %{config: config} do
    assert OhMySmtp.validate_config(config) == :ok
  end

  test "validate_config/1 with invalid config" do
    assert_raise ArgumentError,
                 """
                 expected [:api_key] to be set, got: []
                 """,
                 fn ->
                   OhMySmtp.validate_config([])
                 end
  end
end
