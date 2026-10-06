defmodule Swoosh.Adapters.MailChannels.TLSTest do
  use ExUnit.Case, async: false
  @moduletag :integration
  @moduletag skip: System.get_env("MAILCHANNELS_LOCAL_TLS_FIXTURE") != "1"
  import Swoosh.Email
  alias Swoosh.Adapters.MailChannels

  setup do
    assert {:ok, {127, 0, 0, 1}} == :inet.getaddr(~c"api.mailchannels.net", :inet)
    Application.put_env(:swoosh, :api_client, Swoosh.ApiClient.Req)
    Req.default_options([])
    :ok = :public_key.cacerts_load(~c"/tmp/hex-tls/ca-trusted.pem")
    :ok
  end

  defp deliver do
    email =
      new() |> from("sender@example.test") |> to("to@example.test") |> text_body("synthetic body")

    Swoosh.Mailer.deliver(email, adapter: MailChannels, api_key: "synthetic-key")
  end

  defp server(variant, response, port \\ 443) do
    owner = self()

    pid =
      spawn_link(fn ->
        {:ok, listener} =
          :ssl.listen(port, [
            :binary,
            active: false,
            reuseaddr: true,
            certfile: String.to_charlist("/tmp/hex-tls/#{variant}.pem"),
            keyfile: String.to_charlist("/tmp/hex-tls/#{variant}.key")
          ])

        send(owner, {:ready, self()})
        accept(listener, owner, response, port)
      end)

    assert_receive {:ready, ^pid}, 5000
    on_exit(fn -> Process.exit(pid, :kill) end)
    pid
  end

  defp accept(listener, owner, response, port) do
    case :ssl.transport_accept(listener, 30_000) do
      {:ok, socket} ->
        send(owner, {:connection, port})

        case :ssl.handshake(socket, 5000) do
          {:ok, socket} ->
            case read_request(socket, "") do
              {:ok, request} ->
                send(owner, {:http, port, request})

                case response do
                  :disconnect -> :ok
                  :timeout -> Process.sleep(16_000)
                  bytes -> :ssl.send(socket, bytes)
                end

              _ ->
                :ok
            end

            :ssl.close(socket)

          {:error, _} ->
            :ok
        end

        accept(listener, owner, response, port)

      _ ->
        :ok
    end
  end

  defp read_request(socket, acc) do
    case String.split(acc, "\r\n\r\n", parts: 2) do
      [headers, body] ->
        [_, length] = Regex.run(~r/content-length: (\d+)/i, headers)
        if byte_size(body) >= String.to_integer(length), do: {:ok, acc}, else: recv(socket, acc)

      _ ->
        recv(socket, acc)
    end
  end

  defp recv(socket, acc) do
    case :ssl.recv(socket, 0, 5000) do
      {:ok, data} -> read_request(socket, acc <> data)
      error -> error
    end
  end

  test "real TLS preserves fixed destination, authenticated JSON and empty 202 acceptance" do
    server("valid", "HTTP/1.1 202 Accepted\r\nContent-Length: 0\r\nConnection: close\r\n\r\n")
    assert {:ok, %{}} = deliver()
    assert_receive {:connection, 443}
    assert_receive {:http, 443, request}
    assert request =~ "POST /tx/v1/send HTTP/1.1"
    assert String.downcase(request) =~ "host: api.mailchannels.net"
    assert String.downcase(request) =~ "x-api-key: synthetic-key"
    [_, body] = String.split(request, "\r\n\r\n", parts: 2)

    assert Jason.decode!(body)["content"] == [
             %{"type" => "text/plain", "value" => "synthetic body"}
           ]

    refute_receive {:connection, _}, 300
  end

  test "response content is not decompressed or decoded when classifying acceptance" do
    server(
      "valid",
      "HTTP/1.1 202 Accepted\r\nContent-Encoding: gzip\r\nContent-Length: 8\r\nConnection: close\r\n\r\nnot-gzip"
    )

    assert {:ok, %{}} = deliver()
    assert_receive {:connection, 443}
    assert_receive {:http, 443, request}
    refute String.downcase(request) =~ "accept-encoding:"
    refute_receive {:connection, _}, 300
  end

  test "proxy environment variables do not reroute the authenticated request" do
    variables = ~w(HTTP_PROXY HTTPS_PROXY ALL_PROXY http_proxy https_proxy all_proxy)
    previous = Map.new(variables ++ ~w(NO_PROXY no_proxy), &{&1, System.get_env(&1)})
    Enum.each(variables, &System.put_env(&1, "http://127.0.0.1:444"))
    Enum.each(~w(NO_PROXY no_proxy), &System.put_env(&1, ""))

    on_exit(fn ->
      Enum.each(previous, fn
        {key, nil} -> System.delete_env(key)
        {key, value} -> System.put_env(key, value)
      end)
    end)

    server("valid", "HTTP/1.1 202 Accepted\r\nContent-Length: 0\r\nConnection: close\r\n\r\n")
    server("valid", "", 444)
    assert {:ok, %{}} = deliver()
    assert_receive {:connection, 443}
    assert_receive {:http, 443, _}
    refute_receive {:connection, _}, 300
  end

  for variant <- ["wrong-host", "untrusted"] do
    test "rejects #{variant} certificate before sending key or body" do
      server(unquote(variant), "HTTP/1.1 202 Accepted\r\nContent-Length: 0\r\n\r\n")
      assert {:error, :transport_failure} = deliver()
      assert_receive {:connection, 443}
      refute_receive {:http, _, _}, 300
      refute_receive {:connection, _}, 300
    end
  end

  for status <- [301, 302, 303, 307, 308, 429, 500, 503] do
    test "real TLS status #{status} causes one POST and no redirected request" do
      status = unquote(status)

      server(
        "valid",
        "HTTP/1.1 #{status} Fixture\r\nLocation: https://redirect.example.test:444/leak\r\n" <>
          "Content-Length: 0\r\nConnection: close\r\n\r\n"
      )

      server("valid", "", 444)
      assert {:error, {:http_status, ^status}} = deliver()
      assert_receive {:connection, 443}
      assert_receive {:http, 443, _}
      refute_receive {:connection, _}, 300
      refute_receive {:http, _, _}, 300
    end
  end

  for response <- [
        :disconnect,
        :timeout,
        "HTTP/1.1 202 Accepted\r\nContent-Length: 50\r\nConnection: close\r\n\r\nshort"
      ] do
    test "interrupted response #{inspect(response)} has unknown acceptance and no replay" do
      server("valid", unquote(response))
      assert {:error, :transport_failure} = deliver()
      assert_receive {:connection, 443}
      assert_receive {:http, 443, _}
      refute_receive {:connection, _}, 500
      refute_receive {:http, _, _}, 500
    end
  end
end
