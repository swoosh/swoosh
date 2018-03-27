defmodule Swoosh.Adapters.SparkPostTest do
  use AdapterCase, async: true

  import Swoosh.Email
  alias Swoosh.Adapters.SparkPost

  @success_response """
    {
      "results": {
        "total_rejected_recipients": 0,
        "total_accepted_recipients": 1,
        "id": "11668787484950529"
      }
    }
  """

  setup do
    bypass = Bypass.open
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
    Bypass.expect bypass, fn conn ->
      conn = parse(conn)
      expected_path = "/transmissions"
      body_params = %{
        "content" => %{
          "from" => %{"email" => "tony.stark@example.com", "name" => ""},
          "headers" => %{},
          "html" => "<h1>Hello</h1>",
          "subject" => "Hello, Avengers!",
          "text" => nil,
        },
        "recipients" => [
          %{
            "address" => %{
              "email" => "steve.rogers@example.com",
              "header_to" => "steve.rogers@example.com",
              "name" => ""
            }
          }
        ]
      }
      assert body_params == conn.body_params
      assert expected_path == conn.request_path
      assert "POST" == conn.method

      Plug.Conn.resp(conn, 200, @success_response)
    end

    assert {:ok, Swoosh.json_library.decode!(@success_response)} == SparkPost.deliver(email, config)
  end

  test "delivery/1 with all fields returns :ok", %{bypass: bypass, config: config} do
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
      expected_path = "/transmissions"
      body_params = %{
        "content" => %{
          "from" => %{
            "email" => "tony.stark@example.com",
            "name" => "T Stark"
          },
          "headers" => %{
            "CC" => "thor.odinson@example.com, \"Bruce Banner\" <hulk.smash@example.com>"
          },
          "html" => "<h1>Hello</h1>",
          "reply_to" => "office.avengers@example.com",
          "subject" => "Hello, Avengers!",
          "text" => "Hello",
        },
        "recipients" => [
          %{
            "address" => %{
              "email" => "wasp.avengers@example.com",
              "header_to" => "wasp.avengers@example.com,steve.rogers@example.com",
              "name" => ""
            }
          },
          %{
            "address" => %{
              "email" => "steve.rogers@example.com",
              "header_to" => "wasp.avengers@example.com,steve.rogers@example.com",
              "name" => "Steve Rogers"
            }
          }, %{
            "address" => %{
              "email" => "thor.odinson@example.com",
              "header_to" => "wasp.avengers@example.com,steve.rogers@example.com",
              "name" => ""
            }
          },
          %{
            "address" => %{
              "email" => "hulk.smash@example.com",
              "header_to" => "wasp.avengers@example.com,steve.rogers@example.com",
              "name" => "Bruce Banner"
            }
          },
          %{
            "address" => %{
              "email" => "beast.avengers@example.com",
              "header_to" => "wasp.avengers@example.com,steve.rogers@example.com",
              "name" => ""
            }
          },
          %{
            "address" => %{
              "email" => "hawk.eye@example.com",
              "header_to" => "wasp.avengers@example.com,steve.rogers@example.com",
              "name" => "Clinton Francis Barton"
            }
          }
        ]
      }

      assert body_params == conn.body_params
      assert expected_path == conn.request_path
      assert "POST" == conn.method

      Plug.Conn.resp(conn, 200, @success_response)
    end

    assert {:ok, Swoosh.json_library.decode!(@success_response)} == SparkPost.deliver(email, config)
  end

  test "delivery/1 with custom headers returns :ok", %{bypass: bypass, config: config} do
    email =
      new()
      |> from({"T Stark", "tony.stark@example.com"})
      |> to({"Steve Rogers", "steve.rogers@example.com"})
      |> subject("Hello, Avengers!")
      |> cc("thor.odinson@example.com")
      |> subject("Hello, Avengers!")
      |> html_body("<h1>Hello</h1>")
      |> text_body("Hello")
      |> header("In-Reply-To", "<1234@example.com>")
      |> header("X-Accept-Language", "en")
      |> header("X-Mailer", "swoosh")

    Bypass.expect bypass, fn conn ->
      conn = parse(conn)
      expected_path = "/transmissions"
      body_params = %{
        "content" => %{
          "from" => %{
            "email" => "tony.stark@example.com",
            "name" => "T Stark"
          },
          "headers" => %{
            "CC" => "thor.odinson@example.com",
            "In-Reply-To" => "<1234@example.com>",
            "X-Accept-Language" => "en",
            "X-Mailer" => "swoosh"
          },
          "html" => "<h1>Hello</h1>",
          "text" => "Hello",
          "subject" => "Hello, Avengers!",
        },
        "recipients" => [
          %{
            "address" => %{
              "email" => "steve.rogers@example.com",
              "header_to" => "steve.rogers@example.com",
              "name" => "Steve Rogers"
            }
          },
          %{
            "address" => %{
              "email" => "thor.odinson@example.com",
              "header_to" => "steve.rogers@example.com",
              "name" => ""
            }
          }
        ]
      }

      assert body_params == conn.body_params
      assert expected_path == conn.request_path
      assert "POST" == conn.method

      Plug.Conn.resp(conn, 200, @success_response)
    end

    assert {:ok, Swoosh.json_library.decode!(@success_response)} == SparkPost.deliver(email, config)
  end

  test "delivery/1 with 4xx response", %{bypass: bypass, config: config, valid_email: email} do
    Bypass.expect bypass, fn conn ->
      Plug.Conn.resp(conn, 422, "{}")
    end

    assert {:error, {422, %{}}} = SparkPost.deliver(email, config)
  end

  test "deliver/1 with 5xx response", %{bypass: bypass, valid_email: email, config: config} do
    Bypass.expect bypass, fn conn ->
      Plug.Conn.resp(conn, 500, "{}")
    end

    assert {:error, {500, %{}}} = SparkPost.deliver(email, config)
  end

  test "validate_config/1 with valid config", %{config: config} do
    assert SparkPost.validate_config(config) == :ok
  end

  test "validate_config/1 with invalid config" do
    assert_raise ArgumentError, """
    expected [:api_key] to be set, got: []
    """, fn ->
      SparkPost.validate_config([])
    end
  end
end
