defmodule Swoosh.Adapters.AmazonSesTest do
  use AdapterCase, async: true

  import Swoosh.Email
  alias Swoosh.Adapters.AmazonSes

  @success_response """
  <SendEmailResponse xmlns="https://email.amazonaws.com/doc/2010-03-31/">
    <SendEmailResult>
      <MessageId>000001271b15238a-fd3ae762-2563-11df-8cd4-6d4e828a9ae8-000000</MessageId>
    </SendEmailResult>
    <ResponseMetadata>
      <RequestId>fd3ae762-2563-11df-8cd4-6d4e828a9ae8</RequestId>
    </ResponseMetadata>
  </SendEmailResponse>
  """

  setup do
    bypass = Bypass.open
    config = [
      base_url: "http://localhost:#{bypass.port}",
      access_key: "fake_username",
      secret: "fake_password"
    ]

    valid_email =
      new()
      |> from("guybrush.threepwood@pirates.grog")
      |> to("murry@lechucksship.gov")
      |> subject("Mighty Pirate Newsletter")
      |> body("<h1>Hello</h1>")

    {:ok, bypass: bypass, valid_email: valid_email, config: config}
  end

  test "a sent email results in :ok", %{bypass: bypass, config: config, valid_email: email} do
    expected_raw_message_data """
    From: guybrush.threepwood@pirates.grog
    Subject: Mighty Pirate Newsletter

    <h1>Hello</h1>
    """

    Bypass.expect bypass, fn conn ->
      conn = parse(conn)
      expected_path = "/" <> config[:domain] <> "/messages"
      body_params = URL.encode_query(%{
        "Action" => "SendRawEmail",
        "ToAddresses.member.1" => "murry@lechucksship.gov",
        "RawMessage.Data" => Base.encode64(expected_raw_message_data)
      })
      assert body_params == conn.body_params
      assert expected_path == conn.request_path
      assert "POST" == conn.method

      Plug.Conn.resp(conn, 200, @success_response)
    end

    assert AmazonSes.deliver(email, config) == {:ok, %{id: "000001271b15238a-fd3ae762-2563-11df-8cd4-6d4e828a9ae8-000000"}}
  end

  test "delivery/1 with all fields returns :ok", %{bypass: bypass, config: config} do
    expected_raw_message_data """
    From: "G Threepwood" <guybrush.threepwood@pirates.grog>
    Subject: Mighty Pirate Newsletter

    <h1>Hello</h1>
    """

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
      |> body("<h1>Hello</h1>")

    Bypass.expect bypass, fn conn ->
      conn = parse(conn)
      expected_path = "/" <> config[:domain] <> "/messages"
      body_params = %{
        "Action" => "SendRawEmail"
        "ToAddresses.member.1" => ~s("Murry The Skull" <murry@lechucksship.gov>),
        "ToAddresses.member.2" => "elaine.marley@triisland.gov",
        "CcAddresses.member.1" => ~s("Cannibals" <canni723@monkeyisland.com>),
        "CcAddresses.member.2" => "carla@sworddojo.org",
        "BccAddresses.member.1" => ~s("LeChuck" <lechuck@underworld.com>),
        "BccAddresses.member.2" => "stan@coolshirt.com",
        "RawMessage.Data" => Base.encode64(expected_raw_message_data)
      }

      assert body_params == conn.body_params
      assert expected_path == conn.request_path
      assert "POST" == conn.method

      Plug.Conn.resp(conn, 200, @success_response)
    end

    assert AmazonSes.deliver(email, config) == {:ok, %{id: "000001271b15238a-fd3ae762-2563-11df-8cd4-6d4e828a9ae8-000000"}}
  end

  # test "delivery/1 with custom variables returns :ok", %{bypass: bypass, config: config} do
  #   email =
  #     new()
  #     |> from("guybrush.threepwood@pirates.grog")
  #     |> to("murry@lechucksship.gov")
  #     |> subject("Mighty Pirate Newsletter")
  #     |> html_body("<h1>Hello</h1>")
  #     |> put_provider_option(:custom_vars, %{my_var: %{"my_message_id": 123}, my_other_var: %{"my_other_id": 1, "stuff": 2}})

  #   Bypass.expect bypass, fn conn ->
  #     conn = parse(conn)
  #     expected_path = "/" <> config[:domain] <> "/messages"
  #     body_params = %{"subject" => "Mighty Pirate Newsletter",
  #                     "to" => "murry@lechucksship.gov",
  #                     "from" => "guybrush.threepwood@pirates.grog",
  #                     "html" => "<h1>Hello</h1>",
  #                     "v:my_var" => "{\"my_message_id\":123}",
  #                     "v:my_other_var" => "{\"stuff\":2,\"my_other_id\":1}"}
  #     assert body_params == conn.body_params
  #     assert expected_path == conn.request_path
  #     assert "POST" == conn.method

  #     Plug.Conn.resp(conn, 200, @success_response)
  #   end

  #   assert AmazonSes.deliver(email, config) == {:ok, %{id: "<20111114174239.25659.5817@samples.AmazonSes.org>"}}
  # end

  # test "delivery/1 with custom headers returns :ok", %{bypass: bypass, config: config} do
  #   email =
  #     new()
  #     |> from("guybrush.threepwood@pirates.grog")
  #     |> to("murry@lechucksship.gov")
  #     |> subject("Mighty Pirate Newsletter")
  #     |> html_body("<h1>Hello</h1>")
  #     |> header("In-Reply-To", "<1234@example.com>")
  #     |> header("X-Accept-Language", "en")
  #     |> header("X-Mailer", "swoosh")

  #   Bypass.expect bypass, fn conn ->
  #     conn = parse(conn)
  #     expected_path = "/" <> config[:domain] <> "/messages"
  #     body_params = %{"subject" => "Mighty Pirate Newsletter",
  #                     "to" => "murry@lechucksship.gov",
  #                     "from" => "guybrush.threepwood@pirates.grog",
  #                     "html" => "<h1>Hello</h1>",
  #                     "h:In-Reply-To" => "<1234@example.com>",
  #                     "h:X-Accept-Language" => "en",
  #                     "h:X-Mailer" => "swoosh"}
  #     assert body_params == conn.body_params
  #     assert expected_path == conn.request_path
  #     assert "POST" == conn.method

  #     Plug.Conn.resp(conn, 200, @success_response)
  #   end

  #   assert AmazonSes.deliver(email, config) == {:ok, %{id: "<20111114174239.25659.5817@samples.AmazonSes.org>"}}
  # end

  # test "delivery/1 with 4xx response", %{bypass: bypass, config: config, valid_email: email} do
  #   Bypass.expect bypass, fn conn ->
  #     Plug.Conn.resp(conn, 401, "Forbidden")
  #   end

  #   assert AmazonSes.deliver(email, config) == {:error, {401, "Forbidden"}}
  # end

  # test "deliver/1 with 5xx response", %{bypass: bypass, valid_email: email, config: config} do
  #   Bypass.expect bypass, fn conn ->
  #     Plug.Conn.resp(conn, 500, "{\"errors\":[\"The provided authorization grant is invalid, expired, or revoked\"], \"message\":\"error\"}")
  #   end

  #   assert AmazonSes.deliver(email, config) == {:error, {500, %{"errors" => ["The provided authorization grant is invalid, expired, or revoked"], "message" => "error"}}}
  # end

  test "validate_config/1 with valid config", %{config: config} do
    assert AmazonSes.validate_config(config) == :ok
  end

  test "validate_config/1 with invalid config" do
    assert_raise ArgumentError, """
    expected [:base_url, :access_key, :secret] to be set, got: []
    """, fn ->
      AmazonSes.validate_config([])
    end
  end
end
