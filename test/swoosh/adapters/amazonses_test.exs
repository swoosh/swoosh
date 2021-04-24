defmodule Swoosh.Adapters.AmazonSESTest do
  use Swoosh.AdapterCase, async: true

  import Swoosh.Email
  alias Swoosh.Adapters.AmazonSES

  @success_response """
  <SendEmailResponse>
    <SendEmailResult>
      <MessageId>messageId</MessageId>
    </SendEmailResult>
    <ResponseMetadata>
      <RequestId>requestId</RequestId>
    </ResponseMetadata>
  </SendEmailResponse>
  """

  @error_response """
  <ErrorResponse>
    <Error>
      <Type>ErrorType</Type>
      <Code>ErrorCode</Code>
      <Message>Error Message</Message>
    </Error>
    <RequestId>a97266f7-b062-11e7-b126-6b0f7a9b3379</RequestId>
  </ErrorResponse>
  """

  setup_all do
    config = [
      region: "us-east-1",
      access_key: "test_access",
      secret: "test_secret"
    ]

    valid_email =
      new()
      |> from("guybrush.threepwood@pirates.grog")
      |> to("elaine.marley@triisland.gov")
      |> subject("Mighty Pirate Newsletter")
      |> text_body("Hello")
      |> html_body("<h1>Hello</h1>")

    {:ok, valid_email: valid_email, config: config}
  end

  setup context do
    bypass = Bypass.open()
    config = Keyword.put(context[:config], :host, "http://localhost:#{bypass.port}")

    %{bypass: bypass, config: config}
  end

  test "a sent email results in :ok", %{bypass: bypass, config: config, valid_email: email} do
    Bypass.expect(bypass, fn conn ->
      conn = parse(conn)
      expected_path = "/"

      body_params = %{
        "Action" => "SendRawEmail",
        "Version" => "2010-12-01"
      }

      assert body_params["Action"] == conn.body_params["Action"]
      assert body_params["Version"] == conn.body_params["Version"]
      assert expected_path == conn.request_path
      assert "POST" == conn.method

      Plug.Conn.resp(conn, 200, @success_response)
    end)

    assert AmazonSES.deliver(email, config) == {:ok, %{id: "messageId", request_id: "requestId"}}
  end

  test "a sent email with tags results in :ok", %{bypass: bypass, config: config} do
    email =
      new()
      |> from("guybrush.threepwood@pirates.grog")
      |> to("elaine.marley@triisland.gov")
      |> subject("Mighty Pirate Newsletter")
      |> text_body("Hello")
      |> html_body("<h1>Hello</h1>")
      |> put_provider_option(:tags, [%{name: "name1", value: "test1"}])
      |> put_provider_option(:configuration_set_name, "configuration_set_name1")

    Bypass.expect(bypass, fn conn ->
      conn = parse(conn)
      expected_path = "/"

      body_params = %{
        "Action" => "SendRawEmail",
        "Version" => "2010-12-01",
        "ConfigurationSetName" => "configuration_set_name1",
        "Tags.member.1.Name" => "name1",
        "Tags.member.1.Value" => "test1"
      }

      assert body_params["Action"] == conn.body_params["Action"]
      assert body_params["Version"] == conn.body_params["Version"]
      assert body_params["ConfigurationSetName"] == conn.body_params["ConfigurationSetName"]
      assert body_params["Tags.member.1.Name"] == conn.body_params["Tags.member.1.Name"]
      assert body_params["Tags.member.1.Value"] == conn.body_params["Tags.member.1.Value"]
      assert expected_path == conn.request_path
      assert "POST" == conn.method

      Plug.Conn.resp(conn, 200, @success_response)
    end)

    assert AmazonSES.deliver(email, config) == {:ok, %{id: "messageId", request_id: "requestId"}}
  end

  test "deliver/1 with all fields returns :ok", %{bypass: bypass, config: config} do
    email =
      new()
      |> from({"G Threepwood", "guybrush.threepwood@pirates.grog"})
      |> to({"Murry The Skull", "murry@lechucksship.gov"})
      |> to("elaine.marley@triisland.gov")
      |> cc({"Cannibals", "canni723@monkeyisland.com"})
      |> cc("carla@sworddojo.org")
      |> bcc({"LeChuck", "lechuck@underworld.com"})
      |> bcc("stan@coolshirt.com")
      |> subject("Mighty Pirate Newsletter")
      |> text_body("Hello")
      |> html_body("<h1>Hello</h1>")

    Bypass.expect(bypass, fn conn ->
      conn = parse(conn)
      expected_path = "/"

      body_params = %{
        "Action" => "SendRawEmail",
        "Version" => "2010-12-01"
      }

      assert body_params["Action"] == conn.body_params["Action"]
      assert body_params["Version"] == conn.body_params["Version"]
      assert expected_path == conn.request_path
      assert "POST" == conn.method

      Plug.Conn.resp(conn, 200, @success_response)
    end)

    assert AmazonSES.deliver(email, config) == {:ok, %{id: "messageId", request_id: "requestId"}}
  end

  test "a sent email that returns a api error parses correctly", %{
    bypass: bypass,
    config: config,
    valid_email: email
  } do
    Bypass.expect(bypass, fn conn ->
      conn = parse(conn)
      expected_path = "/"

      assert expected_path == conn.request_path
      assert "POST" == conn.method

      Plug.Conn.resp(conn, 500, @error_response)
    end)

    assert AmazonSES.deliver(email, config) ==
             {:error, %{code: "ErrorCode", message: "Error Message"}}
  end

  test "validate_config/1 with valid config", %{config: config} do
    assert AmazonSES.validate_config(config) == :ok
  end

  test "validate_config/1 with invalid config" do
    assert_raise ArgumentError,
                 """
                 expected [:secret, :access_key, :region] to be set, got: []
                 """,
                 fn ->
                   AmazonSES.validate_config([])
                 end
  end
end
