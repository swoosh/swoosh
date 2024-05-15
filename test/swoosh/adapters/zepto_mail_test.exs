defmodule Swoosh.Adapters.ZeptoMailTest do
  use Swoosh.AdapterCase, async: true

  import Swoosh.Email
  alias Swoosh.Adapters.ZeptoMail

  @success_response """
  {
    "data": [
      {
        "code": "EM_104",
        "additional_info":[],
        "message": "Email request received"
      }
    ],
    "message": "OK",
    "request_id": "2d6f.3dd3c3f49c2fb8fc.m1.3063d370-1063-11ef-a100-525400fa05f6.18f6cfb6a27",
    "object": "email"
  }
  """

  @error_response """
  {
    "error": {
      "code": "TM_3201",
      "details": [
        {
          "code": "GE_102",
          "message": "Mandatory field found empty",
          "target": "subject"
        }
      ],
      "message": "Mandatory Field missing",
      "request_id": "2d6f.3dd3c3f49c2fb8fc.m1.ffaab700-1079-11ef-812f-525400d4bb1c.18f6d90e670"
    }
  }
  """

  setup do
    bypass = Bypass.open()

    config = [
      base_url: "http://localhost:#{bypass.port}",
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
    Bypass.expect(bypass, fn conn ->
      conn = parse(conn)

      body_params = %{
        "subject" => "Hello, Avengers!",
        "to" => [%{"email_address" => %{"address" => "steve.rogers@example.com", "name" => ""}}],
        "from" => %{"address" => "tony.stark@example.com", "name" => ""},
        "reply_to" => [],
        "attachments" => [],
        "inline_images" => [],
        "htmlbody" => "<h1>Hello</h1>"
      }

      assert body_params == conn.body_params
      assert "/email" == conn.request_path
      assert "POST" == conn.method

      assert {"content-type", "application/json"} in conn.req_headers
      assert {"accept", "application/json"} in conn.req_headers
      assert {"authorization", "Zoho-enczapikey fake"} in conn.req_headers

      Plug.Conn.resp(conn, 201, @success_response)
    end)

    assert ZeptoMail.deliver(email, config) ==
             {:ok,
              %{id: "2d6f.3dd3c3f49c2fb8fc.m1.3063d370-1063-11ef-a100-525400fa05f6.18f6cfb6a27"}}
  end

  test "deliver/2 with all fields returns :ok", %{bypass: bypass, config: config} do
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
      |> put_provider_option(:track_opens, true)
      |> put_provider_option(:track_clicks, false)
      |> put_provider_option(:bounce_address, "mission.failed@avengers.com")
      |> put_provider_option(:client_reference, "client-reference")
      |> put_provider_option(:mime_headers, %{
        "x-header-1" => "value 1",
        "x-header-2" => "value 2"
      })

    Bypass.expect(bypass, fn conn ->
      conn = parse(conn)

      mix_content = Base.encode64(File.read!("mix.exs"))
      mix_lock_content = Base.encode64(File.read!("mix.lock"))
      foo_content = Base.encode64("attachment-data with filename and content-type")

      inline_foo_content =
        Base.encode64("attachment-data with file name, content-type, as inline")

      assert match?(
               %{
                 "subject" => "Hello, Avengers!",
                 "to" => [
                   %{
                     "email_address" => %{"address" => "wasp.avengers@example.com", "name" => ""}
                   },
                   %{
                     "email_address" => %{
                       "address" => "steve.rogers@example.com",
                       "name" => "Steve Rogers"
                     }
                   }
                 ],
                 "from" => %{"address" => "tony.stark@example.com", "name" => "T Stark"},
                 "cc" => [
                   %{"email_address" => %{"address" => "thor.odinson@example.com", "name" => ""}},
                   %{
                     "email_address" => %{
                       "address" => "hulk.smash@example.com",
                       "name" => "Bruce Banner"
                     }
                   }
                 ],
                 "bcc" => [
                   %{
                     "email_address" => %{"address" => "beast.avengers@example.com", "name" => ""}
                   },
                   %{
                     "email_address" => %{
                       "address" => "hawk.eye@example.com",
                       "name" => "Clinton Francis Barton"
                     }
                   }
                 ],
                 "reply_to" => [
                   %{
                     "address" => "office.avengers@example.com",
                     "name" => ""
                   }
                 ],
                 "htmlbody" => "<h1>Hello</h1>",
                 "textbody" => "Hello",
                 "track_opens" => true,
                 "track_clicks" => false,
                 "bounce_address" => "mission.failed@avengers.com",
                 "client_reference" => "client-reference",
                 "mime_headers" => %{
                   "x-header-1" => "value 1",
                   "x-header-2" => "value 2"
                 },
                 "attachments" => [
                   %{
                     "mime_type" => "text/plain",
                     "name" => "foo.txt",
                     "content" => ^foo_content
                   },
                   %{
                     "mime_type" => "text/plain",
                     "name" => "mix.exs",
                     "content" => ^mix_content
                   }
                 ],
                 "inline_images" => [
                   %{
                     "mime_type" => "text/plain",
                     "name" => "foo.txt",
                     "content" => ^inline_foo_content,
                     "cid" => nil
                   },
                   %{
                     "mime_type" => "text/plain",
                     "name" => "mix.lock",
                     "content" => ^mix_lock_content,
                     "cid" => "mix.lock"
                   }
                 ]
               },
               conn.body_params
             )

      assert "/email" == conn.request_path
      assert "POST" == conn.method

      content_type = List.keyfind(conn.req_headers, "content-type", 0)
      assert {"content-type", "application/json"} == content_type
      assert {"accept", "application/json"} in conn.req_headers
      assert {"authorization", "Zoho-enczapikey fake"} in conn.req_headers

      Plug.Conn.resp(conn, 201, @success_response)
    end)

    assert ZeptoMail.deliver(email, config) ==
             {:ok,
              %{id: "2d6f.3dd3c3f49c2fb8fc.m1.3063d370-1063-11ef-a100-525400fa05f6.18f6cfb6a27"}}
  end

  test "deliver/2 with attachments from cache store returns :ok", %{
    bypass: bypass,
    config: config,
    valid_email: email
  } do
    email =
      email
      |> put_provider_option(:attachments, ["file-cache-1", "file-cache-2"])
      |> put_provider_option(:inline_images, [
        %{cid: "file1", file_cache_key: "file-cache-1"},
        %{cid: "file2", file_cache_key: "file-cache-2"}
      ])

    Bypass.expect(bypass, fn conn ->
      conn = parse(conn)

      body_params = %{
        "subject" => "Hello, Avengers!",
        "to" => [%{"email_address" => %{"address" => "steve.rogers@example.com", "name" => ""}}],
        "from" => %{"address" => "tony.stark@example.com", "name" => ""},
        "reply_to" => [],
        "htmlbody" => "<h1>Hello</h1>",
        "attachments" => [
          %{"file_cache_key" => "file-cache-1"},
          %{"file_cache_key" => "file-cache-2"}
        ],
        "inline_images" => [
          %{"cid" => "file1", "file_cache_key" => "file-cache-1"},
          %{"cid" => "file2", "file_cache_key" => "file-cache-2"}
        ]
      }

      assert body_params == conn.body_params
      assert "/email" == conn.request_path
      assert "POST" == conn.method

      assert {"content-type", "application/json"} in conn.req_headers
      assert {"accept", "application/json"} in conn.req_headers
      assert {"authorization", "Zoho-enczapikey fake"} in conn.req_headers

      Plug.Conn.resp(conn, 201, @success_response)
    end)

    assert ZeptoMail.deliver(email, config) ==
             {:ok,
              %{id: "2d6f.3dd3c3f49c2fb8fc.m1.3063d370-1063-11ef-a100-525400fa05f6.18f6cfb6a27"}}
  end

  test "deliver/2 with template options returns :ok", %{bypass: bypass, config: config} do
    email =
      new()
      |> from({"T Stark", "tony.stark@example.com"})
      |> to({"Steve Rogers", "steve.rogers@example.com"})
      |> subject("Hello, Avengers!")
      |> attachment(
        Swoosh.Attachment.new(
          "mix.exs",
          content_type: "text/plain"
        )
      )
      |> put_provider_option(:template_key, "template-key")
      |> put_provider_option(:merge_info, %{name: "Tony", team: "Avengers"})

    Bypass.expect(bypass, fn conn ->
      conn = parse(conn)

      body_params = %{
        "template_key" => "template-key",
        "subject" => "Hello, Avengers!",
        "to" => [
          %{
            "email_address" => %{
              "address" => "steve.rogers@example.com",
              "name" => "Steve Rogers"
            }
          }
        ],
        "from" => %{"address" => "tony.stark@example.com", "name" => "T Stark"},
        "reply_to" => [],
        "merge_info" => %{"name" => "Tony", "team" => "Avengers"},
        "attachments" => [
          %{
            "mime_type" => "text/plain",
            "name" => "mix.exs",
            "content" => Base.encode64(File.read!("mix.exs"))
          }
        ]
      }

      assert body_params == conn.body_params
      assert "/email/template" == conn.request_path
      assert "POST" == conn.method

      content_type = List.keyfind(conn.req_headers, "content-type", 0)
      assert {"content-type", "application/json"} == content_type
      assert {"accept", "application/json"} in conn.req_headers
      assert {"authorization", "Zoho-enczapikey fake"} in conn.req_headers

      Plug.Conn.resp(conn, 201, @success_response)
    end)

    assert ZeptoMail.deliver(email, config) ==
             {:ok,
              %{id: "2d6f.3dd3c3f49c2fb8fc.m1.3063d370-1063-11ef-a100-525400fa05f6.18f6cfb6a27"}}
  end

  test "deliver/2 with 4xx response", %{bypass: bypass, config: config, valid_email: email} do
    Bypass.expect(bypass, fn conn ->
      Plug.Conn.resp(conn, 400, @error_response)
    end)

    assert ZeptoMail.deliver(email, config) ==
             {:error, {400, Swoosh.json_library().decode!(@error_response)}}
  end

  test "deliver/2 with 5xx response", %{bypass: bypass, valid_email: email, config: config} do
    Bypass.expect(bypass, fn conn -> Plug.Conn.resp(conn, 500, @error_response) end)

    assert ZeptoMail.deliver(email, config) ==
             {:error, {500, Swoosh.json_library().decode!(@error_response)}}

    Bypass.down(bypass)
    assert ZeptoMail.deliver(email, config) == {:error, :econnrefused}
  end

  test "deliver/2 a sent batch email results in :ok", %{
    bypass: bypass,
    config: config,
    valid_email: email
  } do
    email =
      email
      |> to("wasp.avengers@example.com")
      |> to({"Bruce Banner", "hulk.smash@example.com"})
      |> put_provider_option(:merge_info, %{
        "wasp.avengers@example.com" => %{team: "Avengers 1"},
        "hulk.smash@example.com" => %{team: "Avengers 2"}
      })

    Bypass.expect(bypass, fn conn ->
      conn = parse(conn)

      body_params = %{
        "subject" => "Hello, Avengers!",
        "from" => %{"address" => "tony.stark@example.com", "name" => ""},
        "to" => [
          %{
            "email_address" => %{"address" => "hulk.smash@example.com", "name" => "Bruce Banner"},
            "merge_info" => %{"team" => "Avengers 2"}
          },
          %{
            "email_address" => %{"address" => "wasp.avengers@example.com", "name" => ""},
            "merge_info" => %{"team" => "Avengers 1"}
          },
          %{
            "email_address" => %{"address" => "steve.rogers@example.com", "name" => ""},
            "merge_info" => %{}
          }
        ],
        "reply_to" => [],
        "attachments" => [],
        "inline_images" => [],
        "htmlbody" => "<h1>Hello</h1>"
      }

      assert body_params == conn.body_params
      assert "/email/batch" == conn.request_path
      assert "POST" == conn.method

      assert {"content-type", "application/json"} in conn.req_headers
      assert {"accept", "application/json"} in conn.req_headers
      assert {"authorization", "Zoho-enczapikey fake"} in conn.req_headers

      Plug.Conn.resp(conn, 201, @success_response)
    end)

    config = Keyword.put(config, :type, :batch)

    assert ZeptoMail.deliver(email, config) ==
             {:ok,
              %{id: "2d6f.3dd3c3f49c2fb8fc.m1.3063d370-1063-11ef-a100-525400fa05f6.18f6cfb6a27"}}
  end
end
