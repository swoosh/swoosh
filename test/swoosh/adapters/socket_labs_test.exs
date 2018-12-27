defmodule Swoosh.Adapters.SocketLabsTest do
  use Swoosh.AdapterCase, async: true

  import Swoosh.Email
  alias Swoosh.Adapters.SocketLabs

  @success_response """
    {
      "ErrorCode": "Success",
      "MessageResults": [],
      "TransactionReceipt": null
    }
  """

  setup do
    bypass = Bypass.open()
    config = [base_url: "http://localhost:#{bypass.port}", server_id: "1234", api_key: "some_key"]

    valid_email =
      new()
      |> from("steve.rogers@example.com")
      |> to("tony.stark@example.com")
      |> subject("Hello, Avengers!")
      |> html_body("<h1>Hello</h1>")

    {:ok, bypass: bypass, valid_email: valid_email, config: config}
  end

  test "a sent email results in :ok", %{bypass: bypass, config: config, valid_email: email} do
    Bypass.expect(bypass, fn conn ->
      conn = parse(conn)

      body_params = %{
        "APIKey" => "some_key",
        "Messages" => [
          %{
            "From" => %{
              "emailAddress" => "steve.rogers@example.com"
            },
            "HtmlBody" => "<h1>Hello</h1>",
            "Subject" => "Hello, Avengers!",
            "To" => [
              %{
                "emailAddress" => "tony.stark@example.com"
              }
            ]
          }
        ],
        "serverId" => "1234"
      }

      assert body_params == conn.body_params
      assert "/email" == conn.request_path
      assert "POST" == conn.method

      Plug.Conn.resp(conn, 200, @success_response)
    end)

    assert SocketLabs.deliver(email, config) ==
             {:ok, %{response_code: "Success", message_results: [], receipt: nil}}
  end

  test "delivery/1 with all fields returns :ok", %{bypass: bypass, config: config} do
    email =
      new()
      |> from({"T Stark", "tony.stark@example.com"})
      |> to("wasp.avengers@example.com")
      |> to({"Steve Rogers", "steve.rogers@example.com"})
      |> subject("Hello, Avengers!")
      |> html_body("<h1>Hello</h1>")
      |> cc({"Bruce Banner", "hulk.smash@example.com"})
      |> cc("thor.odinson@example.com")
      |> bcc({"Clinton Francis Barton", "hawk.eye@example.com"})
      |> bcc("beast.avengers@example.com")
      |> reply_to("iron.stark@example.com")
      |> html_body("<h1>Hello</h1>")
      |> text_body("Hello")

    Bypass.expect(bypass, fn conn ->
      conn = parse(conn)

      body_params = %{
        "APIKey" => "some_key",
        "Messages" => [
          %{
            "BCC" => [
              %{"emailAddress" => "beast.avengers@example.com"},
              %{
                "emailAddress" => "hawk.eye@example.com",
                "friendlyName" => "Clinton Francis Barton"
              }
            ],
            "CC" => [
              %{"emailAddress" => "thor.odinson@example.com"},
              %{
                "emailAddress" => "hulk.smash@example.com",
                "friendlyName" => "Bruce Banner"
              }
            ],
            "From" => %{
              "emailAddress" => "tony.stark@example.com",
              "friendlyName" => "T Stark"
            },
            "HtmlBody" => "<h1>Hello</h1>",
            "ReplyTo" => %{"emailAddress" => "iron.stark@example.com"},
            "Subject" => "Hello, Avengers!",
            "TextBody" => "Hello",
            "To" => [
              %{
                "emailAddress" => "steve.rogers@example.com",
                "friendlyName" => "Steve Rogers"
              },
              %{"emailAddress" => "wasp.avengers@example.com"}
            ]
          }
        ],
        "serverId" => "1234"
      }

      assert body_params == conn.body_params
      assert "/email" == conn.request_path
      assert "POST" == conn.method

      Plug.Conn.resp(conn, 200, @success_response)
    end)

    assert SocketLabs.deliver(email, config) ==
             {:ok, %{response_code: "Success", message_results: [], receipt: nil}}
  end

  test "delivery/1 with api template field returns :ok", %{bypass: bypass, config: config} do
    email =
      new()
      |> from({"T Stark", "tony.stark@example.com"})
      |> to("avengers@example.com")
      |> put_provider_option(:api_template, "12345")

    Bypass.expect(bypass, fn conn ->
      conn = parse(conn)

      body_params = %{
        "APIKey" => "some_key",
        "Messages" => [
          %{
            "ApiTemplate" => "12345",
            "From" => %{
              "emailAddress" => "tony.stark@example.com",
              "friendlyName" => "T Stark"
            },
            "Subject" => "",
            "To" => [
              %{
                "emailAddress" => "avengers@example.com"
              }
            ]
          }
        ],
        "serverId" => "1234"
      }

      assert body_params == conn.body_params
      assert "/email" == conn.request_path
      assert "POST" == conn.method

      Plug.Conn.resp(conn, 200, @success_response)
    end)

    assert SocketLabs.deliver(email, config) ==
             {:ok, %{response_code: "Success", message_results: [], receipt: nil}}
  end

  test "delivery/1 with message id field returns :ok", %{bypass: bypass, config: config} do
    email =
      new()
      |> from({"T Stark", "tony.stark@example.com"})
      |> to("avengers@example.com")
      |> put_provider_option(:message_id, "12345")

    Bypass.expect(bypass, fn conn ->
      conn = parse(conn)

      body_params = %{
        "APIKey" => "some_key",
        "Messages" => [
          %{
            "From" => %{
              "emailAddress" => "tony.stark@example.com",
              "friendlyName" => "T Stark"
            },
            "MessageId" => "12345",
            "Subject" => "",
            "To" => [
              %{
                "emailAddress" => "avengers@example.com"
              }
            ]
          }
        ],
        "serverId" => "1234"
      }

      assert body_params == conn.body_params
      assert "/email" == conn.request_path
      assert "POST" == conn.method

      Plug.Conn.resp(conn, 200, @success_response)
    end)

    assert SocketLabs.deliver(email, config) ==
             {:ok, %{response_code: "Success", message_results: [], receipt: nil}}
  end

  test "delivery/1 with mailing id field returns :ok", %{bypass: bypass, config: config} do
    email =
      new()
      |> from({"T Stark", "tony.stark@example.com"})
      |> to("avengers@example.com")
      |> put_provider_option(:mailing_id, "12345")

    Bypass.expect(bypass, fn conn ->
      conn = parse(conn)

      body_params = %{
        "APIKey" => "some_key",
        "Messages" => [
          %{
            "From" => %{
              "emailAddress" => "tony.stark@example.com",
              "friendlyName" => "T Stark"
            },
            "MailingId" => "12345",
            "Subject" => "",
            "To" => [
              %{
                "emailAddress" => "avengers@example.com"
              }
            ]
          }
        ],
        "serverId" => "1234"
      }

      assert body_params == conn.body_params
      assert "/email" == conn.request_path
      assert "POST" == conn.method

      Plug.Conn.resp(conn, 200, @success_response)
    end)

    assert SocketLabs.deliver(email, config) ==
             {:ok, %{response_code: "Success", message_results: [], receipt: nil}}
  end

  test "delivery/1 with charset field returns :ok", %{bypass: bypass, config: config} do
    email =
      new()
      |> from({"T Stark", "tony.stark@example.com"})
      |> to("avengers@example.com")
      |> put_provider_option(:charset, "12345")

    Bypass.expect(bypass, fn conn ->
      conn = parse(conn)

      body_params = %{
        "APIKey" => "some_key",
        "Messages" => [
          %{
            "Charset" => "12345",
            "From" => %{
              "emailAddress" => "tony.stark@example.com",
              "friendlyName" => "T Stark"
            },
            "Subject" => "",
            "To" => [
              %{
                "emailAddress" => "avengers@example.com"
              }
            ]
          }
        ],
        "serverId" => "1234"
      }

      assert body_params == conn.body_params
      assert "/email" == conn.request_path
      assert "POST" == conn.method

      Plug.Conn.resp(conn, 200, @success_response)
    end)

    assert SocketLabs.deliver(email, config) ==
             {:ok, %{response_code: "Success", message_results: [], receipt: nil}}
  end

  test "delivery/1 with headers returns :ok", %{bypass: bypass, config: config} do
    email =
      new()
      |> from({"T Stark", "tony.stark@example.com"})
      |> to("avengers@example.com")
      |> header("Header1", "1234567890")
      |> header("Header2", "12345")

    Bypass.expect(bypass, fn conn ->
      conn = parse(conn)

      body_params = %{
        "APIKey" => "some_key",
        "Messages" => [
          %{
            "CustomHeaders" => %{
              "Header1" => "1234567890",
              "Header2" => "12345"
            },
            "From" => %{
              "emailAddress" => "tony.stark@example.com",
              "friendlyName" => "T Stark"
            },
            "Subject" => "",
            "To" => [
              %{
                "emailAddress" => "avengers@example.com"
              }
            ]
          }
        ],
        "serverId" => "1234"
      }

      assert body_params == conn.body_params
      assert "/email" == conn.request_path
      assert "POST" == conn.method

      Plug.Conn.resp(conn, 200, @success_response)
    end)

    assert SocketLabs.deliver(email, config) ==
             {:ok, %{response_code: "Success", message_results: [], receipt: nil}}
  end

  test "delivery/1 with merge data returns :ok", %{bypass: bypass, config: config} do
    email =
      new()
      |> from({"T Stark", "tony.stark@example.com"})
      |> to("avengers@example.com")
      |> put_provider_option(:merge_data, %{
        "PerMessage" => %{
          "per_message1" => "value1",
          "per_message2" => "value2"
        },
        "Global" => %{
          "global1" => "value1",
          "global2" => "value2"
        }
      })

    Bypass.expect(bypass, fn conn ->
      conn = parse(conn)

      body_params = %{
        "APIKey" => "some_key",
        "Messages" => [
          %{
            "From" => %{
              "emailAddress" => "tony.stark@example.com",
              "friendlyName" => "T Stark"
            },
            "MergeData" => %{
              "PerMessage" => %{"per_message1" => "value1", "per_message2" => "value2"},
              "Global" => %{"global1" => "value1", "global2" => "value2"}
            },
            "Subject" => "",
            "To" => [
              %{
                "emailAddress" => "avengers@example.com"
              }
            ]
          }
        ],
        "serverId" => "1234"
      }

      assert body_params == conn.body_params
      assert "/email" == conn.request_path
      assert "POST" == conn.method

      Plug.Conn.resp(conn, 200, @success_response)
    end)

    assert SocketLabs.deliver(email, config) ==
             {:ok, %{response_code: "Success", message_results: [], receipt: nil}}
  end
end
