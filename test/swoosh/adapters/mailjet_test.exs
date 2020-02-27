defmodule Swoosh.Adapters.MailjetTest do
  use Swoosh.AdapterCase, async: true

  import Swoosh.Email
  alias Swoosh.Adapters.Mailjet

  @firstname "Pan"
  @lastname "Michal"
  @subject "Hello, world!"
  @sender "sender@example.com"
  @receiver "receiver@example.com"
  @developer "developer@example.com"
  @template_id "template_id"
  @custom_id "my-great-custom-id"
  @template_html_content "<h1>Hello, world!</h1>"
  @template_text_content "# Hello, world!"
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
        "Cc":[],
        "Bcc":[]
      }
    ]
  }
  """
  @success_response_many """
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
        "Cc":[],
        "Bcc":[]
      },
      {
        "Status":"success",
        "CustomID":"",
        "To":[
          {
            "Email":"test@example.com",
            "MessageUUID":"22222-22222-22222",
            "MessageID":23456789,
            "MessageHref":"https://api.mailjet.com/v3/REST/message/123456789"
          }
        ],
        "Cc":[],
        "Bcc":[]
      }
    ]
  }
  """
  @error_response_many """
  {
    "Messages": [
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
        "Cc":[],
        "Bcc":[]
      },
      {
        "Errors":[
            {
            "ErrorCode": "mj-0013",
            "ErrorIdentifier": "2978b962-32be-4007-a96e-0388451f1b7a",
            "ErrorMessage": "\\"brokenemail\\" is an invalid email address.",
            "ErrorRelatedTo": ["To[0].Email"],
            "StatusCode": 400
          }
        ],
        "Status": "error"
      }
    ]
  }
  """

  setup do
    bypass = Bypass.open()

    config = [
      base_url: "http://localhost:#{bypass.port}",
      api_key: "public_key",
      secret: "private_key"
    ]

    valid_email =
      new()
      |> from(@sender)
      |> to(@receiver)
      |> subject(@subject)

    {:ok, bypass: bypass, valid_email: valid_email, config: config}
  end

  test "delivery/1 - valid email with html and text body results in message ID",
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
              "Email" => @sender,
              "Name" => ""
            },
            "To" => [
              %{
                "Email" => @receiver,
                "Name" => ""
              }
            ],
            "Subject" => @subject,
            "TextPart" => @template_text_content,
            "HTMLPart" => @template_html_content,
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
      |> text_body(@template_text_content)
      |> html_body(@template_html_content)

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
              "Email" => @sender,
              "Name" => ""
            },
            "To" => [
              %{
                "Email" => @receiver,
                "Name" => ""
              }
            ],
            "Subject" => @subject,
            "TemplateID" => @template_id,
            "TemplateLanguage" => true,
            "TemplateErrorDeliver" => true,
            "TemplateErrorReporting" => %{
              "Email" => @developer,
              "Name" => ""
            },
            "Variables" => %{
              "firstname" => @firstname,
              "lastname" => @lastname
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
      |> put_provider_option(:variables, %{
        firstname: @firstname,
        lastname: @lastname
      })
      |> put_provider_option(:template_id, @template_id)
      |> put_provider_option(:template_error_deliver, true)
      |> put_provider_option(:template_error_reporting, @developer)

    assert Mailjet.deliver(email, config) == {:ok, %{id: 123_456_789}}
  end

  test "delivery/1 - valid email with CustomID", %{
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
              "Email" => @sender,
              "Name" => ""
            },
            "To" => [
              %{
                "Email" => @receiver,
                "Name" => ""
              }
            ],
            "Subject" => @subject,
            "TextPart" => @template_text_content,
            "HTMLPart" => @template_html_content,
            "CustomID" => @custom_id,
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
      |> text_body(@template_text_content)
      |> html_body(@template_html_content)
      |> put_provider_option(:custom_id, @custom_id)

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
      "Status" => "error",
      "Errors" => [
        %{
          "ErrorIdentifier" => "error id",
          "ErrorCode" => "mj-0004",
          "StatusCode" => 400,
          "ErrorMessage" => ~s(Type mismatch. Expected type "array of emails".),
          "ErrorRelatedTo" => ["HTMLPart", "TemplateID"]
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
        "ErrorMessage": "Malformed JSON, please review the syntax and properties types."
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

  test "delivery/1 - sends valid auth header", %{
    bypass: bypass,
    config: config,
    valid_email: email
  } do
    Bypass.expect(bypass, fn conn ->
      conn = parse(conn)
      auth_header = ["Basic #{Base.encode64("public_key:private_key")}"]

      assert ^auth_header = Plug.Conn.get_req_header(conn, "authorization")

      Plug.Conn.resp(conn, 200, @success_response)
    end)

    Mailjet.deliver(email, config)
  end

  test "deliver_many/2 - two valid emails result in two message IDs",
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
              "Email" => @sender,
              "Name" => ""
            },
            "To" => [
              %{
                "Email" => @receiver,
                "Name" => ""
              }
            ],
            "Subject" => @subject,
            "Headers" => %{}
          },
          %{
            "From" => %{
              "Email" => @sender,
              "Name" => ""
            },
            "To" => [
              %{
                "Email" => @receiver,
                "Name" => ""
              }
            ],
            "Subject" => @subject,
            "TemplateID" => @template_id,
            "TemplateLanguage" => true,
            "TemplateErrorDeliver" => true,
            "TemplateErrorReporting" => %{
              "Email" => @developer,
              "Name" => ""
            },
            "Variables" => %{
              "firstname" => @firstname,
              "lastname" => @lastname
            },
            "Headers" => %{}
          }
        ]
      }

      assert body_params == conn.body_params
      assert "/send" == conn.request_path
      assert "POST" == conn.method

      Plug.Conn.resp(conn, 200, @success_response_many)
    end)

    emails = [
      email,
      email
      |> put_provider_option(:variables, %{
        firstname: @firstname,
        lastname: @lastname
      })
      |> put_provider_option(:template_id, @template_id)
      |> put_provider_option(:template_error_deliver, true)
      |> put_provider_option(:template_error_reporting, @developer)
    ]

    assert Mailjet.deliver_many(emails, config) ==
             {:ok, [%{id: 123_456_789}, %{id: 23_456_789}]}
  end

  test "deliver_many/2 - one email results in error",
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
              "Email" => @sender,
              "Name" => ""
            },
            "To" => [
              %{
                "Email" => @receiver,
                "Name" => ""
              }
            ],
            "Subject" => @subject,
            "Headers" => %{}
          },
          %{
            "From" => %{
              "Email" => @sender,
              "Name" => ""
            },
            "To" => [
              %{
                "Email" => "brokenemail",
                "Name" => ""
              }
            ],
            "Subject" => @subject,
            "Headers" => %{}
          }
        ]
      }

      assert body_params == conn.body_params
      assert "/send" == conn.request_path
      assert "POST" == conn.method

      Plug.Conn.resp(conn, 400, @error_response_many)
    end)

    emails = [
      email,
      new()
      |> from(@sender)
      |> to("brokenemail")
      |> subject(@subject)
    ]

    assert Mailjet.deliver_many(emails, config) ==
             {:error,
              {400,
               [
                 %{id: 123_456_789},
                 %{
                   "Errors" => [
                     %{
                       "ErrorCode" => "mj-0013",
                       "ErrorIdentifier" =>
                         "2978b962-32be-4007-a96e-0388451f1b7a",
                       "ErrorMessage" =>
                         "\"brokenemail\" is an invalid email address.",
                       "ErrorRelatedTo" => ["To[0].Email"],
                       "StatusCode" => 400
                     }
                   ],
                   "Status" => "error"
                 }
               ]}}
  end
end
