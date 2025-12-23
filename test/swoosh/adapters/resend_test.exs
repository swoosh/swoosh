defmodule Swoosh.Adapters.ResendTest do
  use Swoosh.AdapterCase, async: true

  import Swoosh.Email
  alias Swoosh.Adapters.Resend

  @example_message_id_1 "049b9217-30b5-4f61-a8e3-4d2d12f9f5a7"
  @example_message_id_2 "159b9217-30b5-4f61-a8e3-4d2d12f9f5b8"

  setup do
    bypass = Bypass.open()

    config = [
      api_key: "re_123456789",
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

  defp make_response(conn, message_id \\ @example_message_id_1) do
    conn
    |> Plug.Conn.resp(200, "{\"id\": \"#{message_id}\"}")
  end

  defp make_batch_response(conn, message_ids) do
    data = Enum.map(message_ids, &%{"id" => &1})
    response = %{"data" => data} |> Jason.encode!()
    Plug.Conn.resp(conn, 200, response)
  end

  test "successful delivery returns :ok", %{bypass: bypass, config: config, valid_email: email} do
    Bypass.expect_once(bypass, "POST", "/emails", fn conn ->
      conn = parse(conn)
      assert get_header(conn, "authorization") == "Bearer re_123456789"
      assert get_header(conn, "content-type") == "application/json"

      assert conn.body_params == %{
               "from" => "tony.stark@example.com",
               "to" => ["steve.rogers@example.com"],
               "subject" => "Hello, Avengers!",
               "html" => "<h1>Hello</h1>",
               "text" => "Hello"
             }

      make_response(conn)
    end)

    assert Resend.deliver(email, config) == {:ok, %{id: @example_message_id_1}}
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
               "from" => "tony.stark@example.com",
               "to" => ["steve.rogers@example.com"],
               "subject" => "Hello, Avengers!",
               "text" => "Hello"
             }

      make_response(conn)
    end)

    assert Resend.deliver(email, config) == {:ok, %{id: @example_message_id_1}}
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
               "from" => "tony.stark@example.com",
               "to" => ["steve.rogers@example.com"],
               "subject" => "Hello, Avengers!",
               "html" => "<h1>Hello</h1>"
             }

      make_response(conn)
    end)

    assert Resend.deliver(email, config) == {:ok, %{id: @example_message_id_1}}
  end

  test "deliver/1 with all fields returns :ok", %{bypass: bypass, config: config} do
    email =
      new()
      |> from({"T Stark", "tony.stark@example.com"})
      |> to({"Steve Rogers", "steve.rogers@example.com"})
      |> to("bruce.banner@example.com")
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
               "from" => "T Stark <tony.stark@example.com>",
               "reply_to" => "hulk.smash@example.com",
               "to" => [
                 "bruce.banner@example.com",
                 "Steve Rogers <steve.rogers@example.com>"
               ],
               "cc" => [
                 "Janet Pym <wasp.avengers@example.com>",
                 "hulk.smash@example.com"
               ],
               "bcc" => [
                 "Henry McCoy <beast.avengers@example.com>",
                 "thor.odinson@example.com"
               ],
               "subject" => "Hello, Avengers!",
               "html" => "<h1>Hello</h1>",
               "text" => "Hello"
             }

      make_response(conn)
    end)

    assert Resend.deliver(email, config) == {:ok, %{id: @example_message_id_1}}
  end

  test "deliver/1 with inline images (CID) returns :ok", %{bypass: bypass, config: config} do
    email =
      new()
      |> from("tony.stark@example.com")
      |> to("steve.rogers@example.com")
      |> subject("Hello with inline image")
      |> html_body(~s(<h1>Hello</h1><img src="cid:logo"/>))
      |> attachment(
        Swoosh.Attachment.new(
          {:data, "fake-image-data"},
          filename: "logo.png",
          content_type: "image/png",
          type: :inline,
          cid: "logo"
        )
      )

    Bypass.expect_once(bypass, "POST", "/emails", fn conn ->
      conn = parse(conn)

      assert %{
               "from" => "tony.stark@example.com",
               "to" => ["steve.rogers@example.com"],
               "subject" => "Hello with inline image",
               "html" => ~s(<h1>Hello</h1><img src="cid:logo"/>),
               "attachments" => [
                 %{
                   "filename" => "logo.png",
                   "content" => _content,
                   "content_id" => "logo"
                 }
               ]
             } = conn.body_params

      make_response(conn)
    end)

    assert Resend.deliver(email, config) == {:ok, %{id: @example_message_id_1}}
  end

  test "deliver/1 with regular attachments returns :ok", %{bypass: bypass, config: config} do
    email =
      new()
      |> from("tony.stark@example.com")
      |> to("steve.rogers@example.com")
      |> subject("Hello, Avengers!")
      |> text_body("Hello")
      |> attachment(Swoosh.Attachment.new("test.txt", content_type: "text/plain", data: "Hello"))

    Bypass.expect_once(bypass, "POST", "/emails", fn conn ->
      conn = parse(conn)

      # Should NOT have content_id for regular attachments
      assert %{
               "from" => "tony.stark@example.com",
               "to" => ["steve.rogers@example.com"],
               "subject" => "Hello, Avengers!",
               "text" => "Hello",
               "attachments" => [
                 %{
                   "filename" => "test.txt",
                   "content" => "SGVsbG8="
                 }
               ]
             } = conn.body_params

      # Verify content_id is NOT present
      [attachment] = conn.body_params["attachments"]
      refute Map.has_key?(attachment, "content_id")

      make_response(conn)
    end)

    assert Resend.deliver(email, config) == {:ok, %{id: @example_message_id_1}}
  end

  test "deliver/1 with tags returns :ok", %{bypass: bypass, config: config} do
    email =
      new()
      |> from("tony.stark@example.com")
      |> to("steve.rogers@example.com")
      |> subject("Hello, Avengers!")
      |> text_body("Hello")
      |> put_provider_option(:tags, [
        %{name: "category", value: "confirm_email"},
        %{name: "user_id", value: "123"}
      ])

    Bypass.expect_once(bypass, "POST", "/emails", fn conn ->
      conn = parse(conn)

      assert conn.body_params == %{
               "from" => "tony.stark@example.com",
               "to" => ["steve.rogers@example.com"],
               "subject" => "Hello, Avengers!",
               "text" => "Hello",
               "tags" => [
                 %{"name" => "category", "value" => "confirm_email"},
                 %{"name" => "user_id", "value" => "123"}
               ]
             }

      make_response(conn)
    end)

    assert Resend.deliver(email, config) == {:ok, %{id: @example_message_id_1}}
  end

  test "deliver/1 with scheduled_at returns :ok", %{bypass: bypass, config: config} do
    scheduled_time = "2024-08-05T11:52:01.858Z"

    email =
      new()
      |> from("tony.stark@example.com")
      |> to("steve.rogers@example.com")
      |> subject("Hello, Avengers!")
      |> text_body("Hello")
      |> put_provider_option(:scheduled_at, scheduled_time)

    Bypass.expect_once(bypass, "POST", "/emails", fn conn ->
      conn = parse(conn)

      assert conn.body_params == %{
               "from" => "tony.stark@example.com",
               "to" => ["steve.rogers@example.com"],
               "subject" => "Hello, Avengers!",
               "text" => "Hello",
               "scheduled_at" => scheduled_time
             }

      make_response(conn)
    end)

    assert Resend.deliver(email, config) == {:ok, %{id: @example_message_id_1}}
  end

  test "deliver/1 with idempotency_key returns :ok", %{bypass: bypass, config: config} do
    idempotency_key = "some-unique-key-123"

    email =
      new()
      |> from("tony.stark@example.com")
      |> to("steve.rogers@example.com")
      |> subject("Hello, Avengers!")
      |> text_body("Hello")
      |> put_provider_option(:idempotency_key, idempotency_key)

    Bypass.expect_once(bypass, "POST", "/emails", fn conn ->
      conn = parse(conn)

      assert get_header(conn, "idempotency-key") == idempotency_key

      assert conn.body_params == %{
               "from" => "tony.stark@example.com",
               "to" => ["steve.rogers@example.com"],
               "subject" => "Hello, Avengers!",
               "text" => "Hello"
             }

      make_response(conn)
    end)

    assert Resend.deliver(email, config) == {:ok, %{id: @example_message_id_1}}
  end

  test "deliver/1 with custom email headers returns :ok", %{bypass: bypass, config: config} do
    email =
      new()
      |> from("tony.stark@example.com")
      |> to("steve.rogers@example.com")
      |> subject("Hello, Avengers!")
      |> text_body("Hello")
      |> header("X-Custom-Header", "CustomValue")
      |> header("X-Another-Header", "AnotherValue")

    Bypass.expect_once(bypass, "POST", "/emails", fn conn ->
      conn = parse(conn)

      assert conn.body_params == %{
               "from" => "tony.stark@example.com",
               "to" => ["steve.rogers@example.com"],
               "subject" => "Hello, Avengers!",
               "text" => "Hello",
               "headers" => [
                 %{"name" => "X-Another-Header", "value" => "AnotherValue"},
                 %{"name" => "X-Custom-Header", "value" => "CustomValue"}
               ]
             }

      make_response(conn)
    end)

    assert Resend.deliver(email, config) == {:ok, %{id: @example_message_id_1}}
  end

  test "deliver/1 with template without variables returns :ok", %{bypass: bypass, config: config} do
    email =
      new()
      |> from("tony.stark@example.com")
      |> to("steve.rogers@example.com")
      |> put_provider_option(:template, %{id: "welcome-template"})

    Bypass.expect_once(bypass, "POST", "/emails", fn conn ->
      conn = parse(conn)

      assert conn.body_params == %{
               "from" => "tony.stark@example.com",
               "to" => ["steve.rogers@example.com"],
               "template" => %{
                 "id" => "welcome-template"
               }
             }

      make_response(conn)
    end)

    assert Resend.deliver(email, config) == {:ok, %{id: @example_message_id_1}}
  end

  test "deliver/1 with template and variables returns :ok", %{bypass: bypass, config: config} do
    email =
      new()
      |> from("tony.stark@example.com")
      |> to("steve.rogers@example.com")
      |> put_provider_option(:template, %{
        id: "welcome-template",
        variables: %{
          name: "Steve Rogers",
          action_url: "https://avengers.com/activate"
        }
      })

    Bypass.expect_once(bypass, "POST", "/emails", fn conn ->
      conn = parse(conn)

      assert conn.body_params == %{
               "from" => "tony.stark@example.com",
               "to" => ["steve.rogers@example.com"],
               "template" => %{
                 "id" => "welcome-template",
                 "variables" => %{
                   "name" => "Steve Rogers",
                   "action_url" => "https://avengers.com/activate"
                 }
               }
             }

      make_response(conn)
    end)

    assert Resend.deliver(email, config) == {:ok, %{id: @example_message_id_1}}
  end

  test "deliver/1 with template can override subject", %{bypass: bypass, config: config} do
    email =
      new()
      |> from("tony.stark@example.com")
      |> to("steve.rogers@example.com")
      |> subject("Custom Subject")
      |> put_provider_option(:template, %{id: "welcome-template"})

    Bypass.expect_once(bypass, "POST", "/emails", fn conn ->
      conn = parse(conn)

      assert conn.body_params == %{
               "from" => "tony.stark@example.com",
               "to" => ["steve.rogers@example.com"],
               "subject" => "Custom Subject",
               "template" => %{
                 "id" => "welcome-template"
               }
             }

      make_response(conn)
    end)

    assert Resend.deliver(email, config) == {:ok, %{id: @example_message_id_1}}
  end

  test "deliver/1 with 400 response", %{bypass: bypass, config: config, valid_email: email} do
    error =
      ~s/{"statusCode": 400, "message": "Missing required field: 'to'", "name": "validation_error"}/

    Bypass.expect_once(bypass, &Plug.Conn.resp(&1, 400, error))

    response =
      {:error,
       {400,
        %{
          "statusCode" => 400,
          "message" => "Missing required field: 'to'",
          "name" => "validation_error"
        }}}

    assert Resend.deliver(email, config) == response
  end

  test "deliver/1 with 429 response", %{bypass: bypass, config: config, valid_email: email} do
    error = ~s/{"statusCode": 429, "message": "Too many requests", "name": "rate_limit_exceeded"}/

    Bypass.expect_once(bypass, &Plug.Conn.resp(&1, 429, error))

    response =
      {:error,
       {429,
        %{
          "statusCode" => 429,
          "message" => "Too many requests",
          "name" => "rate_limit_exceeded"
        }}}

    assert Resend.deliver(email, config) == response
  end

  test "deliver/1 with 5xx response", %{bypass: bypass, config: config, valid_email: email} do
    Bypass.expect_once(bypass, "POST", "/emails", fn conn ->
      assert "/emails" == conn.request_path
      assert "POST" == conn.method
      Plug.Conn.resp(conn, 500, "Internal Server Error")
    end)

    assert Resend.deliver(email, config) == {:error, {500, "Internal Server Error"}}
  end

  test "validate_config/1 with valid config", %{config: config} do
    assert Resend.validate_config(config) == :ok
  end

  test "validate_config/1 with invalid config" do
    assert_raise(
      ArgumentError,
      """
      expected [:api_key] to be set, got: []
      """,
      fn ->
        Resend.validate_config([])
      end
    )
  end

  # ===========================
  # deliver_many/2 tests
  # ===========================

  test "deliver_many/2 without any email" do
    assert Resend.deliver_many([], []) == {:ok, []}
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

    Bypass.expect_once(bypass, "POST", "/emails/batch", fn conn ->
      conn = parse(conn)
      assert get_header(conn, "authorization") == "Bearer re_123456789"

      expected_body_params = %{
        # Plug puts parsed params under the "_json" key when the
        # structure is not a map; otherwise it's just the keys themselves,
        "_json" => [
          %{
            "from" => "tony.stark@example.com",
            "to" => ["steve.rogers@example.com"],
            "subject" => "Hello, Steve!",
            "html" => "<h1>Hello Steve</h1>"
          },
          %{
            "from" => "tony.stark@example.com",
            "to" => ["natasha.romanova@example.com"],
            "subject" => "Hello, Natasha!",
            "html" => "<h1>Hello Natasha</h1>"
          }
        ]
      }

      assert expected_body_params == conn.body_params
      make_batch_response(conn, [@example_message_id_1, @example_message_id_2])
    end)

    assert Resend.deliver_many([email1, email2], config) ==
             {:ok, [%{id: @example_message_id_1}, %{id: @example_message_id_2}]}
  end

  test "deliver_many/2 with different recipients and content", %{bypass: bypass, config: config} do
    email1 =
      new()
      |> from({"Tony Stark", "tony.stark@example.com"})
      |> to({"Steve Rogers", "steve.rogers@example.com"})
      |> cc("nick.fury@example.com")
      |> subject("Meeting Today")
      |> text_body("Don't forget our meeting")
      |> put_provider_option(:tags, [%{name: "category", value: "reminder"}])

    email2 =
      new()
      |> from("tony.stark@example.com")
      |> to("natasha.romanova@example.com")
      |> bcc("director@shield.gov")
      |> subject("Mission Briefing")
      |> html_body("<p>Classified info</p>")
      |> put_provider_option(:tags, [%{name: "category", value: "classified"}])

    Bypass.expect_once(bypass, "POST", "/emails/batch", fn conn ->
      conn = parse(conn)

      assert conn.body_params == %{
               "_json" => [
                 %{
                   "from" => "Tony Stark <tony.stark@example.com>",
                   "to" => ["Steve Rogers <steve.rogers@example.com>"],
                   "cc" => ["nick.fury@example.com"],
                   "subject" => "Meeting Today",
                   "text" => "Don't forget our meeting",
                   "tags" => [%{"name" => "category", "value" => "reminder"}]
                 },
                 %{
                   "from" => "tony.stark@example.com",
                   "to" => ["natasha.romanova@example.com"],
                   "bcc" => ["director@shield.gov"],
                   "subject" => "Mission Briefing",
                   "html" => "<p>Classified info</p>",
                   "tags" => [%{"name" => "category", "value" => "classified"}]
                 }
               ]
             }

      make_batch_response(conn, [@example_message_id_1, @example_message_id_2])
    end)

    assert Resend.deliver_many([email1, email2], config) ==
             {:ok, [%{id: @example_message_id_1}, %{id: @example_message_id_2}]}
  end

  test "deliver_many/2 with templates returns :ok", %{bypass: bypass, config: config} do
    email1 =
      new()
      |> from("tony.stark@example.com")
      |> to("steve.rogers@example.com")
      |> put_provider_option(:template, %{
        id: "welcome-template",
        variables: %{name: "Steve"}
      })

    email2 =
      new()
      |> from("tony.stark@example.com")
      |> to("natasha.romanova@example.com")
      |> put_provider_option(:template, %{
        id: "welcome-template",
        variables: %{name: "Natasha"}
      })

    Bypass.expect_once(bypass, "POST", "/emails/batch", fn conn ->
      conn = parse(conn)

      assert conn.body_params == %{
               "_json" => [
                 %{
                   "from" => "tony.stark@example.com",
                   "to" => ["steve.rogers@example.com"],
                   "template" => %{
                     "id" => "welcome-template",
                     "variables" => %{"name" => "Steve"}
                   }
                 },
                 %{
                   "from" => "tony.stark@example.com",
                   "to" => ["natasha.romanova@example.com"],
                   "template" => %{
                     "id" => "welcome-template",
                     "variables" => %{"name" => "Natasha"}
                   }
                 }
               ]
             }

      make_batch_response(conn, [@example_message_id_1, @example_message_id_2])
    end)

    assert Resend.deliver_many([email1, email2], config) ==
             {:ok, [%{id: @example_message_id_1}, %{id: @example_message_id_2}]}
  end

  test "deliver_many/2 rejects emails with scheduled_at", %{config: config} do
    email =
      new()
      |> from("tony.stark@example.com")
      |> to("steve.rogers@example.com")
      |> subject("Test")
      |> text_body("Test")
      |> put_provider_option(:scheduled_at, "2024-08-05T11:52:01.858Z")

    assert Resend.deliver_many([email], config) ==
             {:error, "scheduled_at is not supported in batch email sending"}
  end

  test "deliver_many/2 rejects emails with attachments", %{config: config} do
    email =
      new()
      |> from("tony.stark@example.com")
      |> to("steve.rogers@example.com")
      |> subject("With attachment")
      |> text_body("See attached")
      |> attachment(
        Swoosh.Attachment.new("file.txt", content_type: "text/plain", data: "Content")
      )

    assert Resend.deliver_many([email], config) ==
             {:error, "attachments are not supported in batch email sending"}
  end

  test "deliver_many/2 rejects if any email has scheduled_at", %{config: config} do
    email1 =
      new()
      |> from("tony.stark@example.com")
      |> to("steve.rogers@example.com")
      |> subject("Test 1")
      |> text_body("Test")

    email2 =
      new()
      |> from("tony.stark@example.com")
      |> to("natasha.romanova@example.com")
      |> subject("Test 2")
      |> text_body("Test")
      |> put_provider_option(:scheduled_at, "2024-08-05T11:52:01.858Z")

    assert Resend.deliver_many([email1, email2], config) ==
             {:error, "scheduled_at is not supported in batch email sending"}
  end

  test "deliver_many/2 rejects if any email has attachments", %{config: config} do
    email1 =
      new()
      |> from("tony.stark@example.com")
      |> to("steve.rogers@example.com")
      |> subject("Test 1")
      |> text_body("Test")

    email2 =
      new()
      |> from("tony.stark@example.com")
      |> to("natasha.romanova@example.com")
      |> subject("Test 2")
      |> text_body("Test")
      |> attachment(
        Swoosh.Attachment.new("file.txt", content_type: "text/plain", data: "Content")
      )

    assert Resend.deliver_many([email1, email2], config) ==
             {:error, "attachments are not supported in batch email sending"}
  end

  test "deliver_many/2 with 400 response", %{bypass: bypass, config: config, valid_email: email} do
    error = ~s/{"statusCode": 400, "message": "Invalid email format", "name": "validation_error"}/
    Bypass.expect_once(bypass, &Plug.Conn.resp(&1, 400, error))

    assert Resend.deliver_many([email], config) ==
             {:error,
              {400,
               %{
                 "statusCode" => 400,
                 "message" => "Invalid email format",
                 "name" => "validation_error"
               }}}
  end

  test "deliver_many/2 with 500 response", %{bypass: bypass, config: config, valid_email: email} do
    Bypass.expect_once(bypass, "POST", "/emails/batch", fn conn ->
      assert conn.request_path == "/emails/batch"
      assert conn.method == "POST"
      Plug.Conn.resp(conn, 500, "Internal Server Error")
    end)

    assert Resend.deliver_many([email], config) == {:error, {500, "Internal Server Error"}}
  end

  defp get_header(conn, key) do
    case Enum.find(conn.req_headers, fn {k, _} -> k == key end) do
      {_, value} -> value
      nil -> nil
    end
  end
end
