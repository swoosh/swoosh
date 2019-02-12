defmodule Swoosh.Adapters.MandrillTest do
  use Swoosh.AdapterCase, async: true

  import Swoosh.Email
  alias Swoosh.Adapters.Mandrill

  @success_response """
    [
      {
        "email": "steve.rogers@example.com",
        "status": "sent",
        "_id": "9",
        "reject_reason" :null
      }
    ]
  """

  @queued_response """
    [
      {
        "email": "steve.rogers@example.com",
        "status": "queued",
        "_id": "9",
        "reject_reason": null
      }
    ]
  """

  setup do
    bypass = Bypass.open
    config = [base_url: "http://localhost:#{bypass.port}",
              api_key: "jarvis"]

    valid_email =
      new()
      |> from({"T Stark", "tony.stark@example.com"})
      |> to("steve.rogers@example.com")
      |> cc({"Bruce Banner", "hulk.smash@example.com"})
      |> subject("Hello, Avengers!")
      |> html_body("<h1>Hello</h1>")

    {:ok, bypass: bypass, config: config, valid_email: valid_email}
  end

  test "a sent email results in :ok", %{bypass: bypass, config: config, valid_email: email} do
    Bypass.expect bypass, fn conn ->
      conn = parse(conn)
      body_params = %{"key" => "jarvis",
                      "message" => %{
                        "subject" => "Hello, Avengers!",
                        "to" => [%{"type" => "cc", "email" => "hulk.smash@example.com", "name" => "Bruce Banner"},
                                 %{"type" => "to", "email" => "steve.rogers@example.com"}],
                        "from_name" => "T Stark",
                        "from_email" => "tony.stark@example.com",
                        "html" => "<h1>Hello</h1>"}}
      assert body_params == conn.body_params
      assert "/messages/send.json" == conn.request_path
      assert "POST" == conn.method

      Plug.Conn.resp(conn, 200, @success_response)
    end

    assert Mandrill.deliver(email, config) == {:ok, %{id: "9"}}
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

    Bypass.expect bypass, fn conn ->
      conn = parse(conn)
      body_params = %{"key" => "jarvis",
                      "message" => %{
                        "subject" => "Hello, Avengers!",
                        "headers" => %{"Reply-To" => "office.avengers@example.com"},
                        "to" => [%{"type" => "bcc", "email" => "beast.avengers@example.com"},
                                 %{"type" => "bcc", "email" => "hawk.eye@example.com", "name" => "Clinton Francis Barton"},
                                 %{"type" => "cc", "email" => "thor.odinson@example.com"},
                                 %{"type" => "cc", "email" => "hulk.smash@example.com", "name" => "Bruce Banner"},
                                 %{"type" => "to", "email" => "wasp.avengers@example.com"},
                                 %{"type" => "to", "email" => "steve.rogers@example.com", "name" => "Steve Rogers"}],
                        "from_name" => "T Stark",
                        "from_email" => "tony.stark@example.com",
                        "html" => "<h1>Hello</h1>",
                        "text" => "Hello"}}
      assert body_params == conn.body_params
      assert "/messages/send.json" == conn.request_path
      assert "POST" == conn.method

      Plug.Conn.resp(conn, 200, @success_response)
    end

    assert Mandrill.deliver(email, config) == {:ok, %{id: "9"}}
  end

  test "deliver/1 with custom headers returns :ok", %{bypass: bypass, config: config} do
    email =
      new()
      |> from({"T Stark", "tony.stark@example.com"})
      |> to({"Steve Rogers", "steve.rogers@example.com"})
      |> reply_to("office.avengers@example.com")
      |> header("In-Reply-To", "<1234@example.com>")
      |> header("X-Accept-Language", "en")
      |> header("X-Mailer", "swoosh")

    Bypass.expect bypass, fn conn ->
      conn = parse(conn)
      body_params = %{"key" => "jarvis",
                      "message" => %{
                        "subject" => "",
                        "headers" => %{
                          "Reply-To" => "office.avengers@example.com",
                          "In-Reply-To" => "<1234@example.com>",
                          "X-Accept-Language" => "en",
                          "X-Mailer" => "swoosh",
                        },
                        "to" => [%{"type" => "to", "email" => "steve.rogers@example.com", "name" => "Steve Rogers"}],
                        "from_name" => "T Stark",
                        "from_email" => "tony.stark@example.com"}}
      assert body_params == conn.body_params
      assert "/messages/send.json" == conn.request_path
      assert "POST" == conn.method

      Plug.Conn.resp(conn, 200, @success_response)
    end

    assert Mandrill.deliver(email, config) == {:ok, %{id: "9"}}
  end

  test "a queued email results in :ok", %{bypass: bypass, config: config, valid_email: email} do
    email = put_provider_option(email, :async, true)
    Bypass.expect bypass, fn conn ->
      conn = parse(conn)
      assert true == conn.body_params["async"]
      assert "POST" == conn.method

      Plug.Conn.resp(conn, 200, @queued_response)
    end

    assert Mandrill.deliver(email, config) == {:ok, %{id: "9"}}
  end

  test "deliver/1 with 2xx response containing errors", %{bypass: bypass, config: config, valid_email: email} do
    Bypass.expect bypass, fn conn ->
      Plug.Conn.resp(conn, 200, "[{\"email\":\"leafybasil.gmail@example.com\",\"status\":\"rejected\",\"_id\":\"e1f1f16d3c6e47c5955ad2b4c3207986\",\"reject_reason\":\"unsigned\"}]")
    end

    assert Mandrill.deliver(email, config) == {:error, %{"_id" => "e1f1f16d3c6e47c5955ad2b4c3207986", "email" => "leafybasil.gmail@example.com", "reject_reason" => "unsigned", "status" => "rejected"}}
  end

  test "deliver/1 with non 2xx response", %{bypass: bypass, config: config, valid_email: email} do
    Bypass.expect bypass, fn conn ->
      Plug.Conn.resp(conn, 500, "{\"status\":\"error\",\"code\":-1,\"name\":\"Invalid_Key\",\"message\":\"Invalid API key\"}")
    end

    assert Mandrill.deliver(email, config) == {:error, {500, %{"code" => -1, "message" => "Invalid API key", "name" => "Invalid_Key", "status" => "error"}}}
  end

  test "validate_config/1 with valid config", %{config: config} do
    assert Mandrill.validate_config(config) == :ok
  end

  test "validate_config/1 with invalid config" do
    assert_raise ArgumentError, """
    expected [:api_key] to be set, got: []
    """, fn ->
      Mandrill.validate_config([])
    end
  end

  test "deliver/1 with template_name calls send-template endpoint", %{bypass: bypass, config: config} do
    email =
      new()
      |> from({"T Stark", "tony.stark@example.com"})
      |> to({"Steve Rogers", "steve.rogers@example.com"})
      |> to("wasp.avengers@example.com")
      |> reply_to("office.avengers@example.com")
      |> subject("Hello, Avengers!")
      |> put_provider_option(:template_name, "welcome")

    Bypass.expect bypass, fn conn ->
      conn = parse(conn)
      assert "/messages/send-template.json" == conn.request_path
      assert "POST" == conn.method

      Plug.Conn.resp(conn, 200, @success_response)
    end

    assert Mandrill.deliver(email, config) == {:ok, %{id: "9"}}
  end

  test "deliver/1 with template_name but without template_content returns :ok", %{bypass: bypass, config: config} do
    email =
      new()
      |> from({"T Stark", "tony.stark@example.com"})
      |> to({"Steve Rogers", "steve.rogers@example.com"})
      |> to("wasp.avengers@example.com")
      |> reply_to("office.avengers@example.com")
      |> subject("Hello, Avengers!")
      |> put_provider_option(:template_name, "welcome")

    Bypass.expect bypass, fn conn ->
      conn = parse(conn)
      body_params = %{"key" => "jarvis",
                      "template_name" => "welcome",
                      "template_content" => [%{"name" => "", "content" => ""}],
                      "message" => %{
                        "subject" => "Hello, Avengers!",
                        "headers" => %{"Reply-To" => "office.avengers@example.com"},
                        "to" => [%{"type" => "to", "email" => "wasp.avengers@example.com"},
                                 %{"type" => "to", "email" => "steve.rogers@example.com", "name" => "Steve Rogers"}],
                        "from_name" => "T Stark",
                        "from_email" => "tony.stark@example.com"}}
      assert body_params == conn.body_params
      assert "/messages/send-template.json" == conn.request_path
      assert "POST" == conn.method

      Plug.Conn.resp(conn, 200, @success_response)
    end

    assert Mandrill.deliver(email, config) == {:ok, %{id: "9"}}
  end


  test "deliver/1 with template_content and template_content returns :ok", %{bypass: bypass, config: config} do
    email =
      new()
      |> from({"T Stark", "tony.stark@example.com"})
      |> to({"Steve Rogers", "steve.rogers@example.com"})
      |> to("wasp.avengers@example.com")
      |> reply_to("office.avengers@example.com")
      |> subject("Hello, Avengers!")
      |> put_provider_option(:template_name, "welcome")
      |> put_provider_option(:template_content, [%{"name" => "START_DATE", "content" => "Next Monday"}])

    Bypass.expect bypass, fn conn ->
      conn = parse(conn)
      body_params = %{"key" => "jarvis",
                      "template_name" => "welcome",
                      "template_content" => [%{"name" => "START_DATE", "content" => "Next Monday"}],
                      "message" => %{
                        "subject" => "Hello, Avengers!",
                        "headers" => %{"Reply-To" => "office.avengers@example.com"},
                        "to" => [%{"type" => "to", "email" => "wasp.avengers@example.com"},
                                 %{"type" => "to", "email" => "steve.rogers@example.com", "name" => "Steve Rogers"}],
                        "from_name" => "T Stark",
                        "from_email" => "tony.stark@example.com"}}
      assert body_params == conn.body_params
      assert "/messages/send-template.json" == conn.request_path
      assert "POST" == conn.method

      Plug.Conn.resp(conn, 200, @success_response)
    end

    assert Mandrill.deliver(email, config) == {:ok, %{id: "9"}}
  end

  test "deliver/1 with template_name returns :ok", %{bypass: bypass, config: config} do
    email =
      new()
      |> from({"T Stark", "tony.stark@example.com"})
      |> to({"Steve Rogers", "steve.rogers@example.com"})
      |> to("wasp.avengers@example.com")
      |> reply_to("office.avengers@example.com")
      |> subject("Hello, Avengers!")
      |> put_provider_option(:template_name, "welcome")

    Bypass.expect bypass, fn conn ->
      conn = parse(conn)
      body_params = %{"key" => "jarvis",
                      "template_name" => "welcome",
                      "template_content" => [%{"name" => "", "content" => ""}],
                      "message" => %{
                        "subject" => "Hello, Avengers!",
                        "headers" => %{"Reply-To" => "office.avengers@example.com"},
                        "to" => [%{"type" => "to", "email" => "wasp.avengers@example.com"},
                                 %{"type" => "to", "email" => "steve.rogers@example.com", "name" => "Steve Rogers"}],
                        "from_name" => "T Stark",
                        "from_email" => "tony.stark@example.com"}}
      assert body_params == conn.body_params
      assert "/messages/send-template.json" == conn.request_path
      assert "POST" == conn.method

      Plug.Conn.resp(conn, 200, @success_response)
    end

    assert Mandrill.deliver(email, config) == {:ok, %{id: "9"}}
  end

  test "deliver/1 with global_merge_vars returns :ok", %{bypass: bypass, config: config} do
    email =
      new()
      |> from({"T Stark", "tony.stark@example.com"})
      |> to({"Steve Rogers", "steve.rogers@example.com"})
      |> to("wasp.avengers@example.com")
      |> reply_to("office.avengers@example.com")
      |> subject("Hello, Avengers!")
      |> put_provider_option(:global_merge_vars, [
        %{"name" => "fullname", "content" => "Steve Rogers"},
        %{"name" => "message", "content" => "Welcome Aboard!!"}
      ])

    Bypass.expect bypass, fn conn ->
      conn = parse(conn)
      body_params = %{"key" => "jarvis",
                      "message" => %{
                        "subject" => "Hello, Avengers!",
                        "headers" => %{"Reply-To" => "office.avengers@example.com"},
                        "to" => [%{"type" => "to", "email" => "wasp.avengers@example.com"},
                                 %{"type" => "to", "email" => "steve.rogers@example.com", "name" => "Steve Rogers"}],
                        "global_merge_vars" => [%{"name" => "fullname", "content" => "Steve Rogers"},
                                                %{"name" => "message", "content" => "Welcome Aboard!!"}],
                        "from_name" => "T Stark",
                        "from_email" => "tony.stark@example.com"}}
      assert body_params == conn.body_params
      assert "/messages/send.json" == conn.request_path
      assert "POST" == conn.method

      Plug.Conn.resp(conn, 200, @success_response)
    end

    assert Mandrill.deliver(email, config) == {:ok, %{id: "9"}}
  end

  test "deliver/1 with merge_vars returns :ok", %{bypass: bypass, config: config} do
    email =
      new()
      |> from({"T Stark", "tony.stark@example.com"})
      |> to({"Steve Rogers", "steve.rogers@example.com"})
      |> to("wasp.avengers@example.com")
      |> reply_to("office.avengers@example.com")
      |> subject("Hello, Avengers!")
      |> put_provider_option(:merge_vars, [%{
          "rcpt" => "steve.rogers@example.com",
          "vars" => [
            %{"name" => "fullname", "content" => "Steve Rogers"}
          ]
        }])

    Bypass.expect bypass, fn conn ->
      conn = parse(conn)
      body_params = %{"key" => "jarvis",
                      "message" => %{
                        "subject" => "Hello, Avengers!",
                        "headers" => %{"Reply-To" => "office.avengers@example.com"},
                        "to" => [%{"type" => "to", "email" => "wasp.avengers@example.com"},
                                 %{"type" => "to", "email" => "steve.rogers@example.com", "name" => "Steve Rogers"}],
                        "merge_vars" => [%{
                          "rcpt" => "steve.rogers@example.com",
                          "vars" => [
                            %{"name" => "fullname", "content" => "Steve Rogers"}
                          ]
                        }],
                        "from_name" => "T Stark",
                        "from_email" => "tony.stark@example.com"}}
      assert body_params == conn.body_params
      assert "/messages/send.json" == conn.request_path
      assert "POST" == conn.method

      Plug.Conn.resp(conn, 200, @success_response)
    end

    assert Mandrill.deliver(email, config) == {:ok, %{id: "9"}}
  end

  test "deliver/1 with metadata returns :ok", %{bypass: bypass, config: config} do
    email =
      new()
      |> from({"T Stark", "tony.stark@example.com"})
      |> to({"Steve Rogers", "steve.rogers@example.com"})
      |> to("wasp.avengers@example.com")
      |> reply_to("office.avengers@example.com")
      |> subject("Hello, Avengers!")
      |> put_provider_option(:metadata, %{
          "rcpt" => "steve.rogers@example.com",
        })

    Bypass.expect bypass, fn conn ->
      conn = parse(conn)
      body_params = %{"key" => "jarvis",
                      "message" => %{
                        "subject" => "Hello, Avengers!",
                        "headers" => %{"Reply-To" => "office.avengers@example.com"},
                        "to" => [%{"type" => "to", "email" => "wasp.avengers@example.com"},
                                 %{"type" => "to", "email" => "steve.rogers@example.com", "name" => "Steve Rogers"}],
                        "metadata" => %{
                          "rcpt" => "steve.rogers@example.com"
                        },
                        "from_name" => "T Stark",
                        "from_email" => "tony.stark@example.com"}}
      assert body_params == conn.body_params
      assert "/messages/send.json" == conn.request_path
      assert "POST" == conn.method

      Plug.Conn.resp(conn, 200, @success_response)
    end

    assert Mandrill.deliver(email, config) == {:ok, %{id: "9"}}
  end
end
