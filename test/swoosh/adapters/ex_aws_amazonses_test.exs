defmodule Swoosh.Adapters.ExAwsAmazonSESTest do
  use Swoosh.AdapterCase, async: true

  import Swoosh.Email
  alias Swoosh.Adapters.ExAwsAmazonSES

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

  setup_all do
    config = [
      region: "us-east-1"
    ]

    valid_email =
      new()
      |> from("guybrush.threepwood@pirates.grog")
      |> to("elaine.marley@triisland.gov")
      |> subject("Mighty Pirate Newsletter")
      |> text_body("Hello")
      |> html_body("<h1>Hello</h1>")

    Application.ensure_all_started(:ex_aws)

    {:ok, valid_email: valid_email, config: config}
  end

  setup context do
    bypass = Bypass.open()
    config = Keyword.put(context[:config], :host, "http://localhost:#{bypass.port}")

    %{bypass: bypass, config: config}
  end

  test "a sent email results in :ok", %{bypass: bypass, config: config, valid_email: email} do
    Application.put_env(:ex_aws, :access_key_id, "FAKE")
    Application.put_env(:ex_aws, :secret_access_key, "FAKE")

    on_exit(fn ->
      Application.put_env(:ex_aws, :access_key_id, nil)
      Application.put_env(:ex_aws, :secret_access_key,nil)
    end)

    Bypass.expect(bypass, fn conn ->
      Plug.Conn.resp(conn, 200, @success_response)
    end)

    assert ExAwsAmazonSES.deliver(email, config) ==
             {:ok, %{id: "messageId", request_id: "requestId"}}
  end

  test "validate_config/1 with valid config", %{config: config} do
    assert ExAwsAmazonSES.validate_config(config) == :ok
  end

  test "validate_config/1 with invalid config" do
    assert_raise ArgumentError,
                 """
                 expected [:region] to be set, got: []
                 """,
                 fn ->
                   ExAwsAmazonSES.validate_config([])
                 end
  end
end
