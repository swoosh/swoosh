defmodule Swoosh.Adapters.ScalewayTest do
  use Swoosh.AdapterCase, async: true

  import Swoosh.Email
  alias Swoosh.Adapters.Scaleway

  @example_message_id "<42.11@relay.example.com>"

  setup do
    bypass = Bypass.open()

    config = [
      secret_key: "123",
      project_id: "ABC",
      base_url: "http://localhost:#{bypass.port}"
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
    |> Plug.Conn.resp(200, """
        {
          "emails": [
            {
              "message_id": "#{@example_message_id}",
              "project_id": "ABC"
            }
          ]
        }
    """)
  end

  test "successful delivery returns :ok", %{bypass: bypass, config: config, valid_email: email} do
    Bypass.expect_once(bypass, "POST", "/emails", fn conn ->
      conn = parse(conn)

      assert conn.body_params == %{
               "from" => %{"email" => "tony.stark@example.com"},
               "to" => [%{"email" => "steve.rogers@example.com"}],
               "project_id" => "ABC",
               "html" => "<h1>Hello</h1>",
               "text" => "Hello",
               "subject" => "Hello, Avengers!"
             }

      make_response(conn)
    end)

    assert Scaleway.deliver(email, config) == {:ok, %{id: "#{@example_message_id}"}}
  end

  test "text-only delivery returns :ok", %{bypass: bypass, config: config} do
    email =
      new()
      |> from("tony.stark@example.com")
      |> to("steve.rogers@example.com")
      |> subject("Hello, Avengers!")
      |> text_body("Hello")

    Bypass.expect_once(bypass, "POST", "/emails", fn conn ->
      conn = parse(conn)

      assert conn.body_params == %{
               "from" => %{"email" => "tony.stark@example.com"},
               "to" => [%{"email" => "steve.rogers@example.com"}],
               "project_id" => "ABC",
               "text" => "Hello",
               "subject" => "Hello, Avengers!"
             }

      make_response(conn)
    end)

    assert Scaleway.deliver(email, config) == {:ok, %{id: "#{@example_message_id}"}}
  end

  test "html-only delivery returns :ok", %{bypass: bypass, config: config} do
    email =
      new()
      |> from("tony.stark@example.com")
      |> to("steve.rogers@example.com")
      |> subject("Hello, Avengers!")
      |> html_body("<h1>Hello</h1>")

    Bypass.expect_once(bypass, "POST", "/emails", fn conn ->
      conn = parse(conn)

      assert conn.body_params == %{
               "from" => %{"email" => "tony.stark@example.com"},
               "to" => [%{"email" => "steve.rogers@example.com"}],
               "project_id" => "ABC",
               "html" => "<h1>Hello</h1>",
               "subject" => "Hello, Avengers!"
             }

      make_response(conn)
    end)

    assert Scaleway.deliver(email, config) == {:ok, %{id: "#{@example_message_id}"}}
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

    Bypass.expect_once(bypass, "POST", "/emails", fn conn ->
      conn = parse(conn)

      assert conn.body_params == %{
               "from" => %{"name" => "T Stark", "email" => "tony.stark@example.com"},
               "to" => [%{"name" => "Steve Rogers", "email" => "steve.rogers@example.com"}],
               "project_id" => "ABC",
               "cc" => [
                 %{"name" => "Janet Pym", "email" => "wasp.avengers@example.com"},
                 %{"email" => "hulk.smash@example.com"}
               ],
               "bcc" => [
                 %{"name" => "Henry McCoy", "email" => "beast.avengers@example.com"},
                 %{"email" => "thor.odinson@example.com"}
               ],
               "text" => "Hello",
               "html" => "<h1>Hello</h1>",
               "subject" => "Hello, Avengers!"
             }

      make_response(conn)
    end)

    assert Scaleway.deliver(email, config) == {:ok, %{id: "#{@example_message_id}"}}
  end

  test "deliver/1 with send_before returns :ok", %{bypass: bypass, config: config} do
    now_plus_one_hour = DateTime.now!("Etc/UTC") |> DateTime.add(3600, :second)

    email =
      new()
      |> from({"T Stark", "tony.stark@example.com"})
      |> to({"Steve Rogers", "steve.rogers@example.com"})
      |> subject("Hello, Avengers!")
      |> put_provider_option(:send_before, now_plus_one_hour)

    Bypass.expect_once(bypass, "POST", "/emails", fn conn ->
      conn = parse(conn)

      assert %{
               "from" => %{"name" => "T Stark", "email" => "tony.stark@example.com"},
               "to" => [%{"name" => "Steve Rogers", "email" => "steve.rogers@example.com"}],
               "project_id" => "ABC",
               "subject" => "Hello, Avengers!",
               "send_before" => now_plus_one_hour_sent
             } = conn.body_params

      {:ok, parsed_sent_schedule_date, 0} = DateTime.from_iso8601(now_plus_one_hour_sent)

      assert parsed_sent_schedule_date == now_plus_one_hour

      make_response(conn)
    end)

    assert Scaleway.deliver(email, config) == {:ok, %{id: "#{@example_message_id}"}}
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

    assert Scaleway.deliver(email, config) == response
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

    assert Scaleway.deliver(email, config) == response
  end

  test "deliver/1 with 5xx response", %{bypass: bypass, config: config, valid_email: email} do
    Bypass.expect_once(bypass, "POST", "/emails", fn conn ->
      assert "/emails" == conn.request_path
      assert "POST" == conn.method
      Plug.Conn.resp(conn, 500, "")
    end)

    assert Scaleway.deliver(email, config) == {:error, {500, ""}}
  end

  test "validate_config/1 with valid config", %{config: config} do
    assert Scaleway.validate_config(config) == :ok
  end

  test "validate_config/1 with invalid config" do
    assert_raise(
      ArgumentError,
      """
      expected [:secret_key, :project_id] to be set, got: []
      """,
      fn ->
        Scaleway.validate_config([])
      end
    )
  end
end
