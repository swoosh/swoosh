defmodule Swoosh.Adapters.MailChannels do
  @moduledoc """
  Sends email using the authenticated MailChannels Email API.

  ## Configuration

  This adapter requires the Req API client. Configure a verified sender domain in
  MailChannels and load the API key from a server-side runtime secret:

      # config/runtime.exs
      config :swoosh, :api_client, Swoosh.ApiClient.Req

      config :sample, Sample.Mailer,
        adapter: Swoosh.Adapters.MailChannels,
        api_key: System.fetch_env!("MAILCHANNELS_API_KEY")

      # lib/sample/mailer.ex
      defmodule Sample.Mailer do
        use Swoosh.Mailer, otp_app: :sample
      end

  See the [Email API documentation](https://docs.mailchannels.com/api-reference/send/send-an-email).
  This uses the authenticated Email API, not the retired Cloudflare Workers endpoint.

  ## Supported fields

  Supports From, To, Cc, Bcc, a non-empty subject, text/HTML content, one Reply-To,
  custom headers, and file/binary/inline attachments. At least one To recipient is
  required by the API, and To, Cc and Bcc together may not exceed 1,000 recipients.
  Bcc recipients remain in their original role. Unsupported provider options, multiple
  Reply-To addresses, structural headers and attachment metadata are rejected.

  Inline attachments use their `cid` (Swoosh defaults it to the filename) as the
  API `content_id`, which must be 1-255 printable ASCII characters without `<`, `>`
  or spaces; pass an explicit `cid:` for filenames that don't qualify.

  ## Responses and transport

  HTTP 202 returns `{:ok, %{id: message_id, request_id: request_id}}` with the values
  from the response body, or `{:ok, %{}}` if it carries none. Acceptance is not
  delivery: final outcomes are reported through MailChannels webhooks, which carry the
  same IDs. A 202 whose result is `"failed"` means MailChannels dropped the message and
  returns `{:error, {:send_failed, ids}}` with the same `ids` map; the failure reason is
  not included. Other statuses return `{:error, {:http_status, status}}`.
  Transport errors return `{:error, :transport_failure}` with unknown acceptance.
  Response bodies, request contents and keys are not included in adapter errors.

  Uses the fixed HTTPS send endpoint, TLS peer verification, bounded timeouts and no
  HTTP retries or redirects. Application/job retries are separate: do not blindly
  retry an uncertain send. Only `Swoosh.ApiClient.Req` is supported. Per-email transport
  options and endpoint overrides are refused; application-level Req settings remain
  trusted. Use current patched Req/Finch/Mint dependencies in deployed applications.
  """
  @behaviour Swoosh.Adapter
  alias Swoosh.Adapters.MailChannels.Message
  @url "https://api.mailchannels.net/tx/v1/send"

  @impl true
  def validate_config(config) do
    case credentials(config) do
      {:ok, _} ->
        :ok

      {:error, _} ->
        raise ArgumentError, "MailChannels requires a valid api_key and the fixed endpoint"
    end
  end

  @impl true
  def validate_dependency, do: Swoosh.Adapter.validate_dependency([{:req, Req}])

  @impl true
  def deliver(email, config \\ []) do
    client = Application.get_env(:swoosh, :api_client)

    with {:ok, key} <- credentials(config),
         :ok <- client_policy(client, email),
         {:ok, payload} <- Message.prepare(email),
         {:ok, body} <- encode(payload) do
      email = Swoosh.Email.put_private(email, :client_options, transport_options())

      headers = [
        {"X-Api-Key", key},
        {"Content-Type", "application/json"},
        {"Accept", "application/json"}
      ]

      post(client, headers, body, email)
    end
  end

  # Req 0.7 introduced Finch option lists. Swoosh also supports Req 0.5/0.6.
  defp transport_options do
    options = [
      redirect: false,
      retry: false,
      raw: true,
      compressed: false,
      receive_timeout: 15_000
    ]

    if Version.compare(to_string(Application.spec(:req, :vsn)), "0.7.0") != :lt do
      options ++
        [
          finch: [
            pool_timeout: 5_000,
            conn_opts: [transport_opts: [timeout: 5_000, verify: :verify_peer]]
          ]
        ]
    else
      options ++
        [
          pool_timeout: 5_000,
          connect_options: [timeout: 5_000, transport_opts: [verify: :verify_peer]]
        ]
    end
  end

  defp credentials(config) do
    if Keyword.keyword?(config) do
      key = Keyword.get(config, :api_key)

      if is_binary(key) and byte_size(key) > 0 and String.valid?(key) and
           not String.match?(key, ~r/[\s\x00-\x1f\x7f]/u) and
           not Enum.any?([:base_url, :url, :endpoint], &Keyword.has_key?(config, &1)) do
        {:ok, key}
      else
        {:error, :invalid_config}
      end
    else
      {:error, :invalid_config}
    end
  end

  defp client_policy(Swoosh.ApiClient.Req, %Swoosh.Email{private: private}) do
    if Enum.any?([:client_options, :hackney_options], &Map.has_key?(private, &1)),
      do: {:error, :unsupported_client_options},
      else: :ok
  end

  defp client_policy(_, _), do: {:error, :unsupported_api_client}

  defp encode(payload) do
    case Swoosh.json_library().encode(payload) do
      {:ok, body} when is_binary(body) -> {:ok, body}
      _ -> {:error, :invalid_payload}
    end
  rescue
    _ -> {:error, :invalid_payload}
  end

  # The API reports per-personalization results inside a 202 body. Swoosh sends one
  # personalization, so the first result describes the whole email.
  defp accepted(body) do
    with true <- is_binary(body) and body != "",
         {:ok, %{} = decoded} <- Swoosh.json_library().decode(body) do
      results = if is_list(decoded["results"]), do: decoded["results"], else: []
      ids = accepted_ids(decoded, results)

      if Enum.any?(results, &(is_map(&1) and &1["status"] == "failed")),
        do: {:error, {:send_failed, ids}},
        else: {:ok, ids}
    else
      _ -> {:ok, %{}}
    end
  end

  defp accepted_ids(decoded, results) do
    case results do
      [%{"message_id" => id} | _] when is_binary(id) -> %{id: id}
      _ -> %{}
    end
    |> then(
      &if is_binary(decoded["request_id"]),
        do: Map.put(&1, :request_id, decoded["request_id"]),
        else: &1
    )
  end

  defp post(client, headers, body, email) do
    case client.post(@url, headers, body, email) do
      {:ok, 202, _, response_body} -> accepted(response_body)
      {:ok, status, _, _} when is_integer(status) -> {:error, {:http_status, status}}
      _ -> {:error, :transport_failure}
    end
  rescue
    _ -> {:error, :transport_failure}
  catch
    :exit, _ -> {:error, :transport_failure}
  end
end
