defmodule Swoosh.Adapters.BrevoTest do
  use Swoosh.AdapterCase, async: true

  import Swoosh.Email
  alias Swoosh.Adapters.Brevo

  @example_message_id_1 "<42.11@relay.example.com>"
  @example_message_id_2 "<53.22@relay.example.com>"

  setup do
    bypass = Bypass.open()

    config = [
      api_key: "123",
      base_url: "http://localhost:#{bypass.port}/v3"
    ]

    valid_email =
      new()
      |> from("tony.stark@example.com")
      |> to("steve.rogers@example.com")
      |> subject("Hello, Avengers!")
      |> html_body("<h1>Hello</h1>")
      |> text_body("Hello")

    {:ok, bypass: bypass, config: config, valid_email: valid_email}
  end

  defp make_response(conn) do
    conn
    |> Plug.Conn.resp(200, "{\"messageId\": \"#{@example_message_id_1}\"}")
  end

  test "successful delivery returns :ok", %{bypass: bypass, config: config, valid_email: email} do
    Bypass.expect_once(bypass, "POST", "/v3/smtp/email", fn conn ->
      conn = parse(conn)

      assert conn.body_params == %{
               "sender" => %{"email" => "tony.stark@example.com"},
               "to" => [%{"email" => "steve.rogers@example.com"}],
               "htmlContent" => "<h1>Hello</h1>",
               "textContent" => "Hello",
               "subject" => "Hello, Avengers!"
             }

      make_response(conn)
    end)

    assert Brevo.deliver(email, config) == {:ok, %{id: "#{@example_message_id_1}"}}
  end

  test "text-only delivery returns :ok", %{bypass: bypass, config: config} do
    email =
      new()
      |> from("tony.stark@example.com")
      |> to("steve.rogers@example.com")
      |> subject("Hello, Avengers!")
      |> text_body("Hello")

    Bypass.expect_once(bypass, "POST", "/v3/smtp/email", fn conn ->
      conn = parse(conn)

      assert conn.body_params == %{
               "sender" => %{"email" => "tony.stark@example.com"},
               "to" => [%{"email" => "steve.rogers@example.com"}],
               "textContent" => "Hello",
               "subject" => "Hello, Avengers!"
             }

      make_response(conn)
    end)

    assert Brevo.deliver(email, config) == {:ok, %{id: "#{@example_message_id_1}"}}
  end

  test "html-only delivery returns :ok", %{bypass: bypass, config: config} do
    email =
      new()
      |> from("tony.stark@example.com")
      |> to("steve.rogers@example.com")
      |> subject("Hello, Avengers!")
      |> html_body("<h1>Hello</h1>")

    Bypass.expect_once(bypass, "POST", "/v3/smtp/email", fn conn ->
      conn = parse(conn)

      assert conn.body_params == %{
               "sender" => %{"email" => "tony.stark@example.com"},
               "to" => [%{"email" => "steve.rogers@example.com"}],
               "htmlContent" => "<h1>Hello</h1>",
               "subject" => "Hello, Avengers!"
             }

      make_response(conn)
    end)

    assert Brevo.deliver(email, config) == {:ok, %{id: "#{@example_message_id_1}"}}
  end

  test "deliver/1 with all fields returns :ok", %{bypass: bypass, config: config} do
    email =
      new()
      |> from({"T Stark", "tony.stark@example.com"})
      |> to({"Steve Rogers", "steve.rogers@example.com"})
      |> reply_to("hulk.smash@example.com")
      |> cc("hulk.smash@example.com")
      |> cc({"Janet Pym", "wasp.avengers@example.com"})
      |> bcc("thor.odinson@example.com")
      |> bcc({"Henry McCoy", "beast.avengers@example.com"})
      |> subject("Hello, Avengers!")
      |> html_body("<h1>Hello</h1>")
      |> text_body("Hello")

    Bypass.expect_once(bypass, "POST", "/v3/smtp/email", fn conn ->
      conn = parse(conn)

      assert conn.body_params == %{
               "sender" => %{"name" => "T Stark", "email" => "tony.stark@example.com"},
               "replyTo" => %{"email" => "hulk.smash@example.com"},
               "to" => [%{"name" => "Steve Rogers", "email" => "steve.rogers@example.com"}],
               "cc" => [
                 %{"name" => "Janet Pym", "email" => "wasp.avengers@example.com"},
                 %{"email" => "hulk.smash@example.com"}
               ],
               "bcc" => [
                 %{"name" => "Henry McCoy", "email" => "beast.avengers@example.com"},
                 %{"email" => "thor.odinson@example.com"}
               ],
               "textContent" => "Hello",
               "htmlContent" => "<h1>Hello</h1>",
               "subject" => "Hello, Avengers!"
             }

      make_response(conn)
    end)

    assert Brevo.deliver(email, config) == {:ok, %{id: "#{@example_message_id_1}"}}
  end

  test "deliver/1 with template_id returns :ok", %{bypass: bypass, config: config} do
    email =
      new()
      |> from({"T Stark", "tony.stark@example.com"})
      |> to({"Steve Rogers", "steve.rogers@example.com"})
      |> subject("Hello, Avengers!")
      |> put_provider_option(:template_id, 42)

    Bypass.expect_once(bypass, "POST", "/v3/smtp/email", fn conn ->
      conn = parse(conn)

      assert conn.body_params == %{
               "sender" => %{"name" => "T Stark", "email" => "tony.stark@example.com"},
               "to" => [%{"name" => "Steve Rogers", "email" => "steve.rogers@example.com"}],
               "subject" => "Hello, Avengers!",
               "templateId" => 42
             }

      make_response(conn)
    end)

    assert Brevo.deliver(email, config) == {:ok, %{id: "#{@example_message_id_1}"}}
  end

  test "deliver/1 with template_id and params returns :ok", %{bypass: bypass, config: config} do
    email =
      new()
      |> from("tony.stark@example.com")
      |> to("steve.rogers@example.com")
      |> subject("Hello, Avengers!")
      |> text_body("Hello")
      |> put_provider_option(:template_id, 42)
      |> put_provider_option(:params, %{
        sample_template_param: "sample value",
        another_one: 99
      })

    Bypass.expect_once(bypass, "POST", "/v3/smtp/email", fn conn ->
      conn = parse(conn)

      assert conn.body_params == %{
               "sender" => %{"email" => "tony.stark@example.com"},
               "to" => [%{"email" => "steve.rogers@example.com"}],
               "textContent" => "Hello",
               "subject" => "Hello, Avengers!",
               "templateId" => 42,
               "params" => %{
                 "sample_template_param" => "sample value",
                 "another_one" => 99
               }
             }

      make_response(conn)
    end)

    assert Brevo.deliver(email, config) == {:ok, %{id: "#{@example_message_id_1}"}}
  end

  test "deliver/1 with template_id using template's sender returns :ok", %{
    bypass: bypass,
    config: config
  } do
    email =
      new()
      |> from("TEMPLATE")
      |> to({"Steve Rogers", "steve.rogers@example.com"})
      |> subject("Hello, Avengers!")
      |> html_body("<h1>Hello</h1>")
      |> text_body("Hello")
      |> put_provider_option(:template_id, "Welcome")

    Bypass.expect_once(bypass, "POST", "/v3/smtp/email", fn conn ->
      conn = parse(conn)

      assert conn.body_params == %{
               "to" => [%{"name" => "Steve Rogers", "email" => "steve.rogers@example.com"}],
               "textContent" => "Hello",
               "htmlContent" => "<h1>Hello</h1>",
               "subject" => "Hello, Avengers!",
               "templateId" => "Welcome"
             }

      make_response(conn)
    end)

    assert Brevo.deliver(email, config) == {:ok, %{id: "#{@example_message_id_1}"}}
  end

  test "deliver/1 with template_id using template's subject returns :ok", %{
    bypass: bypass,
    config: config
  } do
    email =
      new()
      |> from("tony.stark@example.com")
      |> to({"Steve Rogers", "steve.rogers@example.com"})
      |> html_body("<h1>Hello</h1>")
      |> text_body("Hello")
      |> put_provider_option(:template_id, "Welcome")

    Bypass.expect_once(bypass, "POST", "/v3/smtp/email", fn conn ->
      conn = parse(conn)

      assert conn.body_params == %{
               "sender" => %{"email" => "tony.stark@example.com"},
               "to" => [%{"name" => "Steve Rogers", "email" => "steve.rogers@example.com"}],
               "textContent" => "Hello",
               "htmlContent" => "<h1>Hello</h1>",
               "templateId" => "Welcome"
             }

      make_response(conn)
    end)

    assert Brevo.deliver(email, config) == {:ok, %{id: "#{@example_message_id_1}"}}
  end

  test "deliver/1 with scheduled_at returns :ok", %{bypass: bypass, config: config} do
    now_plus_one_hour = DateTime.now!("Etc/UTC") |> DateTime.add(3600, :second)

    email =
      new()
      |> from({"T Stark", "tony.stark@example.com"})
      |> to({"Steve Rogers", "steve.rogers@example.com"})
      |> subject("Hello, Avengers!")
      |> put_provider_option(:schedule_at, now_plus_one_hour)

    Bypass.expect_once(bypass, "POST", "/v3/smtp/email", fn conn ->
      conn = parse(conn)

      assert %{
               "sender" => %{"name" => "T Stark", "email" => "tony.stark@example.com"},
               "to" => [%{"name" => "Steve Rogers", "email" => "steve.rogers@example.com"}],
               "subject" => "Hello, Avengers!",
               "scheduledAt" => now_plus_one_hour_sent
             } = conn.body_params

      {:ok, parsed_sent_schedule_date, 0} = DateTime.from_iso8601(now_plus_one_hour_sent)

      assert parsed_sent_schedule_date == now_plus_one_hour

      make_response(conn)
    end)

    assert Brevo.deliver(email, config) == {:ok, %{id: "#{@example_message_id_1}"}}
  end

  test "deliver/1 with 429 response", %{bypass: bypass, config: config, valid_email: email} do
    error = ~s/{"code": "too_many_requests", "message": "The expected rate limit is exceeded."}/

    Bypass.expect_once(bypass, &Plug.Conn.resp(&1, 429, error))

    response =
      {:error,
       {429,
        %{
          "code" => "too_many_requests",
          "message" => "The expected rate limit is exceeded."
        }}}

    assert Brevo.deliver(email, config) == response
  end

  test "deliver/1 with 4xx response", %{bypass: bypass, config: config, valid_email: email} do
    error = ~s/{"code": "invalid_parameter", "message": "error message explained."}/

    Bypass.expect_once(bypass, &Plug.Conn.resp(&1, 400, error))

    response =
      {:error,
       {400,
        %{
          "code" => "invalid_parameter",
          "message" => "error message explained."
        }}}

    assert Brevo.deliver(email, config) == response
  end

  test "deliver/1 with 5xx response", %{bypass: bypass, config: config, valid_email: email} do
    Bypass.expect_once(bypass, "POST", "/v3/smtp/email", fn conn ->
      assert "/v3/smtp/email" == conn.request_path
      assert "POST" == conn.method
      Plug.Conn.resp(conn, 500, "")
    end)

    assert Brevo.deliver(email, config) == {:error, {500, ""}}
  end

  test "validate_config/1 with valid config", %{config: config} do
    assert Brevo.validate_config(config) == :ok
  end

  test "validate_config/1 with invalid config" do
    assert_raise(
      ArgumentError,
      """
      expected [:api_key] to be set, got: []
      """,
      fn ->
        Brevo.validate_config([])
      end
    )
  end

  test "deliver_many/2 without any email" do
    assert Brevo.deliver_many([], []) == {:ok, []}
  end

  test "deliver_many/2 with two basic emails returns :ok", %{bypass: bypass, config: config} do
    email1 =
      new()
      |> from("tony.stark@example.com")
      |> to("steve.rogers@example.com")
      |> subject("Hello, Steve!")
      |> html_body("<h1>Hello Steve</h1>")

    email2 =
      new()
      |> from("tony.stark@example.com")
      |> to("natasha.romanova@example.com")
      |> subject("Hello, Natasha!")
      |> html_body("<h1>Hello Natasha</h1>")

    Bypass.expect_once(bypass, "POST", "/v3/smtp/email", fn conn ->
      conn = parse(conn)

      assert conn.body_params == %{
               "sender" => %{"email" => "tony.stark@example.com"},
               "subject" => "Hello, Steve!",
               "htmlContent" => "<h1>Hello Steve</h1>",
               "messageVersions" => [
                 %{
                   "to" => [%{"email" => "steve.rogers@example.com"}],
                   "subject" => "Hello, Steve!",
                   "htmlContent" => "<h1>Hello Steve</h1>"
                 },
                 %{
                   "to" => [%{"email" => "natasha.romanova@example.com"}],
                   "subject" => "Hello, Natasha!",
                   "htmlContent" => "<h1>Hello Natasha</h1>"
                 }
               ]
             }

      make_message_versions_response(conn, [@example_message_id_1, @example_message_id_2])
    end)

    assert Brevo.deliver_many([email1, email2], config) ==
             {:ok, [%{id: @example_message_id_1}, %{id: @example_message_id_2}]}
  end

  test "deliver_many/2 with template emails", %{bypass: bypass, config: config} do
    email1 =
      new()
      |> from("tony.stark@example.com")
      |> to("steve.rogers@example.com")
      |> put_provider_option(:template_id, 42)
      |> put_provider_option(:params, %{name: "Steve"})

    email2 =
      new()
      |> from("tony.stark@example.com")
      |> to("natasha.romanova@example.com")
      |> put_provider_option(:template_id, 43)
      |> put_provider_option(:params, %{name: "Natasha"})

    Bypass.expect_once(bypass, "POST", "/v3/smtp/email", fn conn ->
      conn = parse(conn)

      assert conn.body_params == %{
               "sender" => %{"email" => "tony.stark@example.com"},
               "templateId" => 42,
               "messageVersions" => [
                 %{
                   "to" => [%{"email" => "steve.rogers@example.com"}],
                   "templateId" => 42,
                   "params" => %{"name" => "Steve"}
                 },
                 %{
                   "to" => [%{"email" => "natasha.romanova@example.com"}],
                   "templateId" => 43,
                   "params" => %{"name" => "Natasha"}
                 }
               ]
             }

      make_message_versions_response(conn, [@example_message_id_1, @example_message_id_2])
    end)

    assert Brevo.deliver_many([email1, email2], config) ==
             {:ok, [%{id: @example_message_id_1}, %{id: @example_message_id_2}]}
  end

  defp make_message_versions_response(conn, message_ids) do
    response = %{"messageIds" => message_ids} |> Jason.encode!()
    Plug.Conn.resp(conn, 200, response)
  end

  test "deliver_many/2 with 400 response", %{bypass: bypass, config: config, valid_email: email} do
    error = ~s/{"code": "missing_parameter", "message": "subject is required"}/
    Bypass.expect_once(bypass, &Plug.Conn.resp(&1, 400, error))

    assert Brevo.deliver_many([email], config) ==
             {:error, {400, %{"code" => "missing_parameter", "message" => "subject is required"}}}
  end

  test "deliver_many/2 with 500 response", %{bypass: bypass, config: config, valid_email: email} do
    Bypass.expect_once(bypass, "POST", "/v3/smtp/email", fn conn ->
      assert conn.request_path == "/v3/smtp/email"
      assert conn.method == "POST"
      Plug.Conn.resp(conn, 500, "some error")
    end)

    assert Brevo.deliver_many([email], config) == {:error, {500, "some error"}}
  end
end
