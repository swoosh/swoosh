defmodule Swoosh.Adapters.MailgunTest do
  use Swoosh.AdapterCase, async: true

  import Swoosh.Email
  alias Swoosh.Adapters.Mailgun

  @success_response """
    {
      "message": "Queued. Thank you.",
      "id": "<20111114174239.25659.5817@samples.mailgun.org>"
    }
  """

  setup do
    bypass = Bypass.open()

    config = [
      base_url: "http://localhost:#{bypass.port}",
      api_key: "fake",
      domain: "avengers.com"
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
      expected_path = "/" <> config[:domain] <> "/messages"

      body_params = %{
        "subject" => "Hello, Avengers!",
        "to" => "steve.rogers@example.com",
        "from" => "tony.stark@example.com",
        "html" => "<h1>Hello</h1>"
      }

      assert body_params == conn.body_params
      assert expected_path == conn.request_path
      assert "POST" == conn.method

      assert {"content-type", "application/x-www-form-urlencoded"} in conn.req_headers
      assert {"content-length", "118"} in conn.req_headers
      assert {"authorization", "Basic YXBpOmZha2U="} in conn.req_headers

      Plug.Conn.resp(conn, 200, @success_response)
    end)

    assert Mailgun.deliver(email, config) ==
             {:ok, %{id: "<20111114174239.25659.5817@samples.mailgun.org>"}}
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
      |> attachment(
        Swoosh.Attachment.new(
          "mix.exs",
          content_type: "text/plain"
        )
      )
      |> attachment(
        Swoosh.Attachment.new(
          "mix.lock",
          content_type: "text/plain",
          type: :inline
        )
      )
      |> attachment(
        Swoosh.Attachment.new(
          {:data, "attachment-data with filename and content-type"},
          filename: "foo.txt",
          content_type: "text/plain"
        )
      )
      |> attachment(
        Swoosh.Attachment.new(
          {:data, "attachment-data with file name, content-type, as inline"},
          filename: "foo.txt",
          content_type: "text/plain",
          type: :inline
        )
      )
      |> put_provider_option(:custom_vars, %{"key" => "value"})

    Bypass.expect(bypass, fn conn ->
      conn = parse(conn)
      expected_path = "/" <> config[:domain] <> "/messages"

      assert match?(
               %{
                 "subject" => "Hello, Avengers!",
                 "to" => ~s(wasp.avengers@example.com, "Steve Rogers" <steve.rogers@example.com>),
                 "bcc" =>
                   ~s(beast.avengers@example.com, "Clinton Francis Barton" <hawk.eye@example.com>),
                 "cc" => ~s(thor.odinson@example.com, "Bruce Banner" <hulk.smash@example.com>),
                 "h:Reply-To" => "office.avengers@example.com",
                 "from" => ~s("T Stark" <tony.stark@example.com>),
                 "text" => "Hello",
                 "html" => "<h1>Hello</h1>",
                 "h:X-Mailgun-Variables" => "{\"key\":\"value\"}",
                 "attachment" => %Plug.Upload{
                   path: attachment_path,
                   content_type: "text/plain",
                   filename: "mix.exs"
                 },
                 "inline" => %Plug.Upload{
                   path: inline_path,
                   content_type: "text/plain",
                   filename: "mix.lock"
                 }
               }
               when is_binary(attachment_path) and is_binary(inline_path),
               conn.body_params
             )

      assert expected_path == conn.request_path
      assert "POST" == conn.method

      content_type = List.keyfind(conn.req_headers, "content-type", 0)
      assert {"content-type", "multipart/form-data; boundary=" <> _} = content_type
      assert {"authorization", "Basic YXBpOmZha2U="} in conn.req_headers

      Plug.Conn.resp(conn, 200, @success_response)
    end)

    assert Mailgun.deliver(email, config) ==
             {:ok, %{id: "<20111114174239.25659.5817@samples.mailgun.org>"}}
  end

  test "deliver/1 with custom variables returns :ok", %{bypass: bypass, config: config} do
    custom_vars = %{
      my_var: [%{my_message_id: 123}],
      my_other_var: %{my_other_id: 1, stuff: 2}
    }

    email =
      new()
      |> from("tony.stark@example.com")
      |> to("steve.rogers@example.com")
      |> subject("Hello, Avengers!")
      |> html_body("<h1>Hello</h1>")
      |> put_provider_option(:custom_vars, custom_vars)

    Bypass.expect(bypass, fn conn ->
      conn = parse(conn)
      expected_path = "/" <> config[:domain] <> "/messages"

      body_params = %{
        "subject" => "Hello, Avengers!",
        "to" => "steve.rogers@example.com",
        "from" => "tony.stark@example.com",
        "html" => "<h1>Hello</h1>",
        "h:X-Mailgun-Variables" => Swoosh.json_library().encode!(custom_vars)
      }

      assert body_params == conn.body_params
      assert expected_path == conn.request_path
      assert "POST" == conn.method

      Plug.Conn.resp(conn, 200, @success_response)
    end)

    assert Mailgun.deliver(email, config) ==
             {:ok, %{id: "<20111114174239.25659.5817@samples.mailgun.org>"}}
  end

  test "deliver/1 with multiple reply_to returns :ok", %{bypass: bypass, config: config} do
    email =
      new()
      |> from({"T Stark", "tony.stark@example.com"})
      |> to({"Steve Rogers", "steve.rogers@example.com"})
      |> reply_to(["office.avengers@example.com", "javis.gpt@example.com"])
      |> subject("Hello, Avengers!")
      |> html_body("<h1>Hello</h1>")

    Bypass.expect(bypass, fn conn ->
      conn = parse(conn)
      expected_path = "/" <> config[:domain] <> "/messages"

      body_params = %{
        "subject" => "Hello, Avengers!",
        "to" => ~s("Steve Rogers" <steve.rogers@example.com>),
        "h:Reply-To" => "office.avengers@example.com, javis.gpt@example.com",
        "from" => ~s("T Stark" <tony.stark@example.com>),
        "html" => "<h1>Hello</h1>"
      }

      assert body_params == conn.body_params
      assert expected_path == conn.request_path
      assert "POST" == conn.method

      Plug.Conn.resp(conn, 200, @success_response)
    end)

    assert Mailgun.deliver(email, config) ==
             {:ok, %{id: "<20111114174239.25659.5817@samples.mailgun.org>"}}
  end

  test "deliver/1 with sending options returns :ok", %{bypass: bypass, config: config} do
    email =
      new()
      |> from("tony.stark@example.com")
      |> to("steve.rogers@example.com")
      |> subject("Hello, Avengers!")
      |> html_body("<h1>Hello</h1>")
      |> put_provider_option(:sending_options, %{dkim: "yes", tracking: "no"})

    Bypass.expect(bypass, fn conn ->
      conn = parse(conn)
      expected_path = "/" <> config[:domain] <> "/messages"

      body_params = %{
        "subject" => "Hello, Avengers!",
        "to" => "steve.rogers@example.com",
        "from" => "tony.stark@example.com",
        "html" => "<h1>Hello</h1>",
        "o:dkim" => "yes",
        "o:tracking" => "no"
      }

      assert body_params == conn.body_params
      assert expected_path == conn.request_path
      assert "POST" == conn.method

      Plug.Conn.resp(conn, 200, @success_response)
    end)

    assert Mailgun.deliver(email, config) ==
             {:ok, %{id: "<20111114174239.25659.5817@samples.mailgun.org>"}}
  end

  test "deliver/1 with template options returns :ok", %{bypass: bypass, config: config} do
    email =
      new()
      |> from("tony.stark@example.com")
      |> to("steve.rogers@example.com")
      |> subject("Hello, Avengers!")
      |> html_body("<h1>Hello</h1>")
      |> put_provider_option(:template_name, "avengers-templates")
      |> put_provider_option(:template_options, %{
        version: "initial",
        text: "yes",
        variables: %{a: 1}
      })

    Bypass.expect(bypass, fn conn ->
      conn = parse(conn)
      expected_path = "/" <> config[:domain] <> "/messages"

      body_params = %{
        "subject" => "Hello, Avengers!",
        "to" => "steve.rogers@example.com",
        "from" => "tony.stark@example.com",
        "html" => "<h1>Hello</h1>",
        "template" => "avengers-templates",
        "t:version" => "initial",
        "t:text" => "yes",
        "t:variables" => Swoosh.json_library().encode!(%{a: 1})
      }

      assert body_params == conn.body_params
      assert expected_path == conn.request_path
      assert "POST" == conn.method

      Plug.Conn.resp(conn, 200, @success_response)
    end)

    assert Mailgun.deliver(email, config) ==
             {:ok, %{id: "<20111114174239.25659.5817@samples.mailgun.org>"}}
  end

  test "deliver/1 with recipient variables returns :ok", %{bypass: bypass, config: config} do
    recipient_vars = %{
      "steve.rogers@example.com": %{var1: 123},
      "juan.diaz@example.com": %{var1: 456}
    }

    email =
      new()
      |> from("tony.stark@example.com")
      |> to(["steve.rogers@example.com", "juan.diaz@example.com"])
      |> subject("Hello, Avengers!")
      |> html_body("<h1>Hello</h1>")
      |> put_provider_option(:recipient_vars, recipient_vars)

    Bypass.expect(bypass, fn conn ->
      conn = parse(conn)
      expected_path = "/" <> config[:domain] <> "/messages"

      body_params = %{
        "subject" => "Hello, Avengers!",
        "to" => "steve.rogers@example.com, juan.diaz@example.com",
        "from" => "tony.stark@example.com",
        "html" => "<h1>Hello</h1>",
        "recipient-variables" => Swoosh.json_library().encode!(recipient_vars)
      }

      assert body_params == conn.body_params
      assert expected_path == conn.request_path
      assert "POST" == conn.method

      Plug.Conn.resp(conn, 200, @success_response)
    end)

    assert Mailgun.deliver(email, config) ==
             {:ok, %{id: "<20111114174239.25659.5817@samples.mailgun.org>"}}
  end

  test "deliver/1 with tags returns :ok", %{bypass: bypass, config: config} do
    email =
      new()
      |> from("tony.stark@example.com")
      |> to("steve.rogers@example.com")
      |> subject("Hello, Avengers!")
      |> html_body("<h1>Hello</h1>")
      |> put_provider_option(:tags, ["worldwide-peace", "unity"])

    Bypass.expect(bypass, fn conn ->
      conn = parse(conn)
      expected_path = "/" <> config[:domain] <> "/messages"

      body_params = %{
        "subject" => "Hello, Avengers!",
        "to" => "steve.rogers@example.com",
        "from" => "tony.stark@example.com",
        "html" => "<h1>Hello</h1>",
        "o:tag" => ["worldwide-peace", "unity"]
      }

      assert body_params == conn.body_params
      assert expected_path == conn.request_path
      assert "POST" == conn.method

      Plug.Conn.resp(conn, 200, @success_response)
    end)

    assert Mailgun.deliver(email, config) ==
             {:ok, %{id: "<20111114174239.25659.5817@samples.mailgun.org>"}}
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

    Bypass.expect(bypass, fn conn ->
      conn = parse(conn)
      expected_path = "/" <> config[:domain] <> "/messages"

      body_params = %{
        "subject" => "Hello, Avengers!",
        "to" => "steve.rogers@example.com",
        "from" => "tony.stark@example.com",
        "html" => "<h1>Hello</h1>",
        "h:In-Reply-To" => "<1234@example.com>",
        "h:X-Accept-Language" => "en",
        "h:X-Mailer" => "swoosh"
      }

      assert body_params == conn.body_params
      assert expected_path == conn.request_path
      assert "POST" == conn.method

      Plug.Conn.resp(conn, 200, @success_response)
    end)

    assert Mailgun.deliver(email, config) ==
             {:ok, %{id: "<20111114174239.25659.5817@samples.mailgun.org>"}}
  end

  test "deliver/1 with 4xx response", %{bypass: bypass, config: config, valid_email: email} do
    Bypass.expect(bypass, fn conn ->
      Plug.Conn.resp(conn, 401, "Forbidden")
    end)

    assert Mailgun.deliver(email, config) == {:error, {401, "Forbidden"}}
  end

  test "deliver/1 with 5xx response", %{bypass: bypass, valid_email: email, config: config} do
    Bypass.expect(bypass, fn conn ->
      Plug.Conn.resp(
        conn,
        500,
        "{\"errors\":[\"The provided authorization grant is invalid, expired, or revoked\"], \"message\":\"error\"}"
      )
    end)

    assert Mailgun.deliver(email, config) ==
             {:error,
              {500,
               %{
                 "errors" => ["The provided authorization grant is invalid, expired, or revoked"],
                 "message" => "error"
               }}}
  end

  test "validate_config/1 with valid config", %{config: config} do
    assert Mailgun.validate_config(config) == :ok
  end

  test "validate_config/1 with invalid config" do
    assert_raise ArgumentError,
                 """
                 expected [:domain, :api_key] to be set, got: []
                 """,
                 fn ->
                   Mailgun.validate_config([])
                 end
  end

  test "encode_body/1 sets valid content length" do
    params = %{
      to: "\"Steve Rogers\" <steve.rogers@example.com>",
      from: "\"T Stark\" <tony.stark@example.com>",
      subject: "Hello, Avengers!",
      html: "<h1>Hello</h1>",
      text: "Hello"
    }

    assert {"application/x-www-form-urlencoded", 174, _body} = Mailgun.encode_body(params)
  end

  test "encode_body/1 sets valid content length for attachments" do
    params = %{
      to: "\"Steve Rogers\" <steve.rogers@example.com>",
      from: "\"T Stark\" <tony.stark@example.com>",
      subject: "Hello, Avengers!",
      html: "<h1>Hello</h1>",
      text: "Hello",
      attachments: [
        Multipart.Part.binary_body("foo")
      ]
    }

    assert {"multipart/form-data; boundary=" <> _, 647, _body} = Mailgun.encode_body(params)
  end
end
