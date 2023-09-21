defmodule Swoosh.Adapters.MsGraphTest do
  use Swoosh.AdapterCase, async: true

  import Swoosh.Email
  alias Swoosh.Adapters.MsGraph

  @success_response ""

  setup do
    bypass = Bypass.open()

    config = [
      base_url: "http://localhost:#{bypass.port}",
      access_token_fn: fn -> "fake-token" end
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
      # TODO(@justindotpub): when calling parse, a 500 is always returned with no error details.
      # conn = parse(conn)
      from_email = email.from |> elem(1)
      expected_path = "/users/" <> from_email <> "/sendMail"

      # TODO: conn.body_params isn't accessible, and perhaps that's because parse(conn) failed so I skipped it?
      # body = MsGraph.encode_body(email, config)
      # assert body == conn.body_params

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
      # conn = parse(conn)
      expected_path = "/users/" <> from_email <> "/sendMail"

      # body_params = %{
      #   "subject" => "Hello, Avengers!",
      #   "to" => ~s(wasp.avengers@example.com, "Steve Rogers" <steve.rogers@example.com>),
      #   "bcc" => ~s(beast.avengers@example.com, "Clinton Francis Barton" <hawk.eye@example.com>),
      #   "cc" => ~s(thor.odinson@example.com, "Bruce Banner" <hulk.smash@example.com>),
      #   "h:Reply-To" => "office.avengers@example.com",
      #   "from" => ~s("T Stark" <tony.stark@example.com>),
      #   "text" => "Hello",
      #   "html" => "<h1>Hello</h1>",
      #   "h:X-MsGraph-Variables" => "{\"key\":\"value\"}",
      #   "template" => "avengers-templates"
      # }

      # assert body_params == conn.body_params
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
      # conn = parse(conn)
      expected_path = "/users/" <> from_email <> "/sendMail"

      # TODO(@justindotpub): base64 decode the body and check the headers

      # assert body_params == conn.body_params
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
                 expected [:access_token_fn] to be set, got: []
                 """,
                 fn ->
                   MsGraph.validate_config([])
                 end
  end
end
