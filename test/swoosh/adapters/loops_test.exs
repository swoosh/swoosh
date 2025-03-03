defmodule Swoosh.Adapters.LoopsTest do
  use Swoosh.AdapterCase, async: true

  import Swoosh.Email
  alias Swoosh.Adapters.Loops

  setup do
    bypass = Bypass.open()

    config = [
      api_key: "123",
      base_url: "http://localhost:#{bypass.port}/v3"
    ]

    valid_email =
      new()
      |> to("steve.rogers@example.com")
      |> put_provider_option(:transactional_id, "clfq6dinn000yl70fgwwyp82l")

    {:ok, bypass: bypass, config: config, valid_email: valid_email}
  end

  defp make_response(conn) do
    conn
    |> Plug.Conn.resp(200, "{\"success\": true}")
  end

  test "successful delivery returns :ok", %{bypass: bypass, config: config, valid_email: email} do
    Bypass.expect_once(bypass, "POST", "/v3/transactional", fn conn ->
      conn = parse(conn)

      assert conn.body_params == %{
               "email" => "steve.rogers@example.com",
               "transactionalId" => "clfq6dinn000yl70fgwwyp82l",
               "addToAudience" => false,
               "dataVariables" => %{}
             }

      make_response(conn)
    end)

    assert Loops.deliver(email, config) == {:ok, %{}}
  end

  test "deliver/1 with params returns :ok", %{bypass: bypass, config: config, valid_email: email} do
    email =
      email
      |> put_provider_option(:data_variables, %{
        sample_template_param: "sample value",
        another_one: 99
      })

    Bypass.expect_once(bypass, "POST", "/v3/transactional", fn conn ->
      conn = parse(conn)

      assert conn.body_params == %{
               "email" => "steve.rogers@example.com",
               "transactionalId" => "clfq6dinn000yl70fgwwyp82l",
               "addToAudience" => false,
               "dataVariables" => %{
                 "sample_template_param" => "sample value",
                 "another_one" => 99
               }
             }

      make_response(conn)
    end)

    assert Loops.deliver(email, config) == {:ok, %{}}
  end

  test "deliver/1 with attachments returns :ok", %{
    bypass: bypass,
    config: config,
    valid_email: email
  } do
    email =
      email
      |> attachment(%Swoosh.Attachment{
        content_type: "text/plain",
        data: "this is an attachment",
        filename: "example.txt",
        type: :attachment,
        headers: []
      })

    Bypass.expect_once(bypass, "POST", "/v3/transactional", fn conn ->
      conn = parse(conn)

      assert conn.body_params == %{
               "email" => "steve.rogers@example.com",
               "transactionalId" => "clfq6dinn000yl70fgwwyp82l",
               "addToAudience" => false,
               "dataVariables" => %{},
               "attachments" => [
                 %{
                   "filename" => "example.txt",
                   "contentType" => "text/plain",
                   "data" => "dGhpcyBpcyBhbiBhdHRhY2htZW50"
                 }
               ]
             }

      make_response(conn)
    end)

    assert Loops.deliver(email, config) == {:ok, %{}}
  end

  test "deliver/1 with 4xx response", %{bypass: bypass, config: config, valid_email: email} do
    error =
      ~s/{"success": false, "error": {"path": "dataVariables", "message": "Missing required fields: login_url"}}/

    Bypass.expect_once(bypass, &Plug.Conn.resp(&1, 400, error))

    response =
      {:error,
       {400,
        %{
          "success" => false,
          "error" => %{
            "path" => "dataVariables",
            "message" => "Missing required fields: login_url"
          }
        }}}

    assert Loops.deliver(email, config) == response
  end

  test "deliver/1 with 5xx response", %{bypass: bypass, config: config, valid_email: email} do
    Bypass.expect_once(bypass, "POST", "/v3/transactional", &Plug.Conn.resp(&1, 500, ""))

    assert Loops.deliver(email, config) == {:error, {500, ""}}
  end

  test "validate_config/1 with valid config", %{config: config} do
    assert Loops.validate_config(config) == :ok
  end

  test "validate_config/1 with invalid config" do
    assert_raise(
      ArgumentError,
      """
      expected [:api_key] to be set, got: []
      """,
      fn ->
        Loops.validate_config([])
      end
    )
  end
end
