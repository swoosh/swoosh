defmodule Swoosh.Adapters.MailChannelsTest do
  use ExUnit.Case, async: false
  import Swoosh.Email
  alias Swoosh.Adapters.MailChannels

  setup do
    client = Application.get_env(:swoosh, :api_client)
    defaults = Req.default_options()
    Application.put_env(:swoosh, :api_client, Swoosh.ApiClient.Req)

    on_exit(fn ->
      Application.put_env(:swoosh, :api_client, client)
      Req.default_options(defaults)
    end)

    :ok
  end

  defp email,
    do:
      new()
      |> from("sender@example.test")
      |> to("to@example.test")
      |> subject("synthetic-subject")
      |> text_body("private-body")

  defp deliver,
    do: Swoosh.Mailer.deliver(email(), adapter: MailChannels, api_key: "synthetic-key")

  defp response(status, body) do
    owner = self()

    Req.default_options(
      adapter: fn request ->
        send(owner, {:request, request})
        {request, %Req.Response{status: status, body: body}}
      end
    )
  end

  test "native Mailer accepts empty 202 without inventing an ID" do
    response(202, "")
    assert {:ok, %{}} = deliver()
    assert_receive {:request, request}
    assert URI.to_string(request.url) == "https://api.mailchannels.net/tx/v1/send"
    assert request.method == :post
    assert Req.Request.get_header(request, "x-api-key") == ["synthetic-key"]

    assert Jason.decode!(request.body)["content"] == [
             %{"type" => "text/plain", "value" => "private-body"}
           ]

    assert request.options.retry == false
    assert request.options.redirect == false

    if Version.compare(to_string(Application.spec(:req, :vsn)), "0.7.0") != :lt do
      assert request.options.finch[:conn_opts][:transport_opts][:verify] == :verify_peer
    else
      assert request.options.connect_options[:transport_opts][:verify] == :verify_peer
    end

    refute_receive {:request, _}
  end

  test "202 body with ids is surfaced" do
    response(
      202,
      ~s({"request_id":"r1","results":[{"index":0,"message_id":"m1","status":"sent"}]})
    )

    assert {:ok, %{id: "m1", request_id: "r1"}} = deliver()
  end

  test "202 body reporting a failed result is an error carrying ids but not the reason" do
    response(
      202,
      ~s({"request_id":"r1","results":[{"index":0,"message_id":"m1","status":"failed","reason":"to@example.test rejected"}]})
    )

    assert {:error, {:send_failed, %{id: "m1", request_id: "r1"} = ids}} = deliver()
    assert map_size(ids) == 2
  end

  test "202 body without results still surfaces the request id" do
    response(202, ~s({"request_id":"r1"}))
    assert {:ok, %{request_id: "r1"}} = deliver()
  end

  test "non-202 statuses are bounded errors, with no response content or retry" do
    for status <- [200, 204, 301, 302, 303, 307, 308, 400, 401, 403, 429, 500, 503] do
      response(status, "synthetic-key private-body")
      assert {:error, {:http_status, ^status}} = deliver()
      assert_receive {:request, _}
      refute_receive {:request, _}
    end
  end

  test "transport errors and exceptions never return request contents" do
    Req.default_options(
      adapter: fn request -> {request, %Req.TransportError{reason: :timeout}} end
    )

    assert {:error, :transport_failure} = deliver()
    Req.default_options(adapter: fn _ -> raise "synthetic-key private-body" end)
    assert {:error, :transport_failure} = deliver()
  end

  test "invalid credentials and endpoint overrides fail before HTTP without inspecting config" do
    response(202, "")

    for config <- [
          [api_key: ""],
          [api_key: "secret\r\nx"],
          [api_key: "secret", base_url: "https://evil.test"]
        ] do
      assert {:error, :invalid_config} = MailChannels.deliver(email(), config)

      assert_raise ArgumentError,
                   "MailChannels requires a valid api_key and the fixed endpoint",
                   fn ->
                     MailChannels.validate_config(config)
                   end
    end

    refute_receive {:request, _}
  end

  test "unsupported clients and email overrides fail before HTTP" do
    response(202, "")

    for key <- [:client_options, :hackney_options] do
      assert {:error, :unsupported_client_options} =
               MailChannels.deliver(put_private(email(), key, redirect: true),
                 api_key: "synthetic-key"
               )
    end

    for client <- [Swoosh.ApiClient.Hackney, Swoosh.ApiClient.Finch, __MODULE__] do
      Application.put_env(:swoosh, :api_client, client)

      assert {:error, :unsupported_api_client} =
               MailChannels.deliver(email(), api_key: "synthetic-key")
    end

    refute_receive {:request, _}
  end
end
