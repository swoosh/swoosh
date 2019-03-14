defmodule Swoosh.Adapters.MailjetTest do
  use Swoosh.AdapterCase, async: true

  import Swoosh.Email
  alias Swoosh.Adapters.Mailjet

  @success_response """
    {
      "Messages":[
        {
            "Status":"success",
            "CustomID":"",
            "To":[
              {
                  "Email":"michal@example.com",
                  "MessageUUID":"12345-12345-12345",
                  "MessageID":123456789,
                  "MessageHref":"https://api.mailjet.com/v3/REST/message/123456789"
              }
            ],
            "Cc":[

            ],
            "Bcc":[

            ]
        }
      ]
    }
  """

  setup do
    bypass = Bypass.open()

    config = [
      base_url: "http://localhost:#{bypass.port}",
      public_key: "public_key",
      private_key: "private_key"
    ]

    valid_email =
      new()
      |> from("sender@example.com")
      |> to("receiver@example.com")
      |> subject("Hello, world!")

    {:ok, bypass: bypass, valid_email: valid_email, config: config}
  end

  test "delivery/1 - valid email with html body results in message ID", %{
    bypass: bypass,
    config: config,
    valid_email: email
  } do
    Bypass.expect(bypass, fn conn ->
      conn = parse(conn)

      body_params = %{
        "Messages" => [
          %{
            "From" => %{
              "Email" => "sender@example.com",
              "Name" => ""
            },
            "To" => [
              %{
                "Email" => "receiver@example.com",
                "Name" => ""
              }
            ],
            "Subject" => "Hello, world!",
            "HTMLPart" => "<h1>Hello, world!</h1>",
            "Headers" => %{}
          }
        ]
      }

      assert body_params == conn.body_params
      assert "/send" == conn.request_path
      assert "POST" == conn.method

      Plug.Conn.resp(conn, 200, @success_response)
    end)

    email = email |> html_body("<h1>Hello, world!</h1>")

    assert Mailjet.deliver(email, config) == {:ok, %{id: 123_456_789}}
  end

  test "delivery/1 - valid email with template ID and variables results in message ID",
       %{
         bypass: bypass,
         config: config,
         valid_email: email
       } do
    Bypass.expect(bypass, fn conn ->
      conn = parse(conn)

      body_params = %{
        "Messages" => [
          %{
            "From" => %{
              "Email" => "sender@example.com",
              "Name" => ""
            },
            "To" => [
              %{
                "Email" => "receiver@example.com",
                "Name" => ""
              }
            ],
            "Subject" => "Hello, world!",
            "TemplateID" => "template id",
            "TemplateLanguage" => true,
            "Variables" => %{
              "firstname" => "Pan",
              "lastname" => "Michal"
            },
            "Headers" => %{}
          }
        ]
      }

      assert body_params == conn.body_params
      assert "/send" == conn.request_path
      assert "POST" == conn.method

      Plug.Conn.resp(conn, 200, @success_response)
    end)

    email =
      email
      |> put_provider_option(:variables, %{firstname: "Pan", lastname: "Michal"})
      |> put_provider_option(:template_id, "template id")

    assert Mailjet.deliver(email, config) == {:ok, %{id: 123_456_789}}
  end

  test "delivery/1 - single 4xx error response from Send API", %{
    bypass: bypass,
    config: config,
    valid_email: email
  } do
    Bypass.expect(bypass, fn conn ->
      error_response = ~s"""
      {
        "Messages":[
          {
            "Status": "error",
            "Errors": [
              {
                "ErrorIdentifier": "error id",
                "ErrorCode": "mj-0004",
                "StatusCode": 400,
                "ErrorMessage": "Type mismatch. Expected type \\"array of emails\\".",
                "ErrorRelatedTo": ["HTMLPart", "TemplateID"]
              }
            ]
          }
        ]
      }
      """

      Plug.Conn.resp(conn, 400, error_response)
    end)

    error_result = %{
      "Messages" => [
        %{
          "Status" => "error",
          "Errors" => [
            %{
              "ErrorIdentifier" => "error id",
              "ErrorCode" => "mj-0004",
              "StatusCode" => 400,
              "ErrorMessage" =>
                ~s(Type mismatch. Expected type "array of emails".),
              "ErrorRelatedTo" => ["HTMLPart", "TemplateID"]
            }
          ]
        }
      ]
    }

    assert Mailjet.deliver(email, config) == {:error, {400, error_result}}
  end

  test "delivery/1 - global 400 error from Send API", %{
    bypass: bypass,
    config: config,
    valid_email: email
  } do
    Bypass.expect(bypass, fn conn ->
      error_response = """
      {
        "ErrorIdentifier":"error id",
        "ErrorCode":"mj-0002",
        "StatusCode":400,
        "ErrorMessage":
        "Malformed JSON, please review the syntax and properties types."
      }
      """

      Plug.Conn.resp(conn, 400, error_response)
    end)

    error_result = %{
      "ErrorIdentifier" => "error id",
      "ErrorCode" => "mj-0002",
      "StatusCode" => 400,
      "ErrorMessage" =>
        "Malformed JSON, please review the syntax and properties types."
    }

    assert Mailjet.deliver(email, config) == {:error, {400, error_result}}
  end
end
