defmodule Swoosh.Adapters.MsGraphTest do
  use Swoosh.AdapterCase, async: true

  import Swoosh.Email
  alias Swoosh.Adapters.MsGraph

  @success_response ""

  setup do
    bypass = Bypass.open()

    config = [
      base_url: "http://localhost:#{bypass.port}",
      auth: fn -> "fake-token" end
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

      from_email = email.from |> elem(1)
      expected_path = "/users/" <> from_email <> "/sendMail"

      {:ok, body, conn} = Plug.Conn.read_body(conn, [])
      decoded_body = Base.decode64!(body)

      parts = decoded_body |> String.split("\r\n")

      assert "Content-Type: text/html;" in parts
      assert "From: tony.stark@example.com" in parts
      assert "To: steve.rogers@example.com" in parts
      assert "Subject: Hello, Avengers!" in parts

      assert expected_path == conn.request_path
      assert "POST" == conn.method

      Plug.Conn.resp(conn, 202, @success_response)
    end)

    assert MsGraph.deliver(email, config) ==
             {:ok, %{}}
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

    from_email = email.from |> elem(1)

    Bypass.expect(bypass, fn conn ->
      conn = parse(conn)
      expected_path = "/users/" <> from_email <> "/sendMail"

      {:ok, body, conn} = Plug.Conn.read_body(conn, [])
      decoded_body = Base.decode64!(body)

      parts = decoded_body |> String.split("\r\n")

      assert "From: T Stark <tony.stark@example.com>" in parts

      to = Enum.find(parts, fn part -> String.starts_with?(part, "To:") end)
      assert String.contains?(to, "wasp.avengers@example.com")
      assert String.contains?(to, "Steve Rogers <steve.rogers@example.com>")

      cc = Enum.find(parts, fn part -> String.starts_with?(part, "Cc:") end)
      assert String.contains?(cc, "thor.odinson@example.com")
      assert String.contains?(cc, "Bruce Banner <hulk.smash@example.com>")

      assert "Reply-To: office.avengers@example.com" in parts
      assert "Subject: Hello, Avengers!" in parts
      assert "Content-Type: text/html;" in parts
      assert "Content-Type: text/plain;" in parts
      assert "<h1>Hello</h1>" in parts
      assert "Hello" in parts

      assert expected_path == conn.request_path
      assert "POST" == conn.method

      Plug.Conn.resp(conn, 202, @success_response)
    end)

    assert MsGraph.deliver(email, config) ==
             {:ok, %{}}
  end

  test "deliver/1 with custom headers returns :ok", %{bypass: bypass, config: config} do
    email =
      new()
      |> from("tony.stark@example.com")
      |> to("steve.rogers@example.com")
      |> subject("Hello, Avengers!")
      |> html_body("<h1>Hello</h1>")
      |> header("In-Reply-To", "<1234@example.com>")
      |> header("X-Accept-Language", "en")
      |> header("X-Mailer", "swoosh")

    from_email = email.from |> elem(1)

    Bypass.expect(bypass, fn conn ->
      conn = parse(conn)
      expected_path = "/users/" <> from_email <> "/sendMail"

      {:ok, body, conn} = Plug.Conn.read_body(conn, [])
      decoded_body = Base.decode64!(body)

      parts = decoded_body |> String.split("\r\n")

      assert "In-Reply-To: <1234@example.com>" in parts
      assert "X-Accept-Language: en" in parts
      assert "X-Mailer: swoosh" in parts

      assert expected_path == conn.request_path
      assert "POST" == conn.method

      Plug.Conn.resp(conn, 202, @success_response)
    end)

    assert MsGraph.deliver(email, config) ==
             {:ok, %{}}
  end

  test "deliver/1 with 4xx response", %{bypass: bypass, config: config, valid_email: email} do
    Bypass.expect(bypass, fn conn ->
      Plug.Conn.resp(conn, 401, "Forbidden")
    end)

    assert MsGraph.deliver(email, config) == {:error, {401, "Forbidden"}}
  end

  test "validate_config/1 with valid config", %{config: config} do
    assert MsGraph.validate_config(config) == :ok
  end

  test "validate_config/1 with invalid config" do
    assert_raise ArgumentError,
                 """
                 expected [:auth] to be set, got: []
                 """,
                 fn ->
                   MsGraph.validate_config([])
                 end
  end

  test ":auth config as anonymous fn succeeds", %{
    bypass: bypass,
    config: config,
    valid_email: email
  } do
    config = config |> Keyword.put(:auth, fn -> "fake-token-from-fn" end)

    Bypass.expect(bypass, fn conn ->
      conn = parse(conn)

      assert {"authorization", "Bearer fake-token-from-fn"} in conn.req_headers

      Plug.Conn.resp(conn, 202, @success_response)
    end)

    assert MsGraph.deliver(email, config) ==
             {:ok, %{}}
  end

  test ":auth config as string succeeds", %{bypass: bypass, config: config, valid_email: email} do
    config = config |> Keyword.put(:auth, "fake-token-from-string")

    Bypass.expect(bypass, fn conn ->
      conn = parse(conn)

      assert {"authorization", "Bearer fake-token-from-string"} in conn.req_headers

      Plug.Conn.resp(conn, 202, @success_response)
    end)

    assert MsGraph.deliver(email, config) ==
             {:ok, %{}}
  end

  test ":auth config as MFA tuple succeeds", %{bypass: bypass, config: config, valid_email: email} do
    config = config |> Keyword.put(:auth, {__MODULE__, :auth, ["a", "b", "c"]})

    Bypass.expect(bypass, fn conn ->
      conn = parse(conn)

      assert {"authorization", "Bearer fake-token-from-mfa-tuple"} in conn.req_headers

      Plug.Conn.resp(conn, 202, @success_response)
    end)

    assert MsGraph.deliver(email, config) ==
             {:ok, %{}}
  end

  test ":url config utilizes given url in full", %{
    bypass: bypass,
    config: config,
    valid_email: email
  } do
    custom_path = "/v1.0/some_other_custom_path"
    url = "http://localhost:#{bypass.port}#{custom_path}"
    config = config |> Keyword.put(:url, url)

    Bypass.expect(bypass, fn conn ->
      conn = parse(conn)

      assert custom_path == conn.request_path

      Plug.Conn.resp(conn, 202, @success_response)
    end)

    assert MsGraph.deliver(email, config) ==
             {:ok, %{}}
  end

  def auth(_a, _b, _c) do
    "fake-token-from-mfa-tuple"
  end
end
