defmodule Swoosh.Adapters.AzureCommunicationServices do
  @moduledoc ~S"""
  An adapter that sends email using the Azure Communication Services (ACS) Email API.

  For reference:
  [Azure Communication Services Email API docs](https://learn.microsoft.com/en-us/rest/api/communication/email/email/send?view=rest-communication-email-2025-09-01)

  **This adapter requires an API Client.** Swoosh comes with Hackney, Finch and Req out of the box.
  See the [installation section](https://hexdocs.pm/swoosh/Swoosh.html#module-installation)
  for details.

  ## Configuration options

  * `:endpoint` (required) - The ACS resource endpoint, e.g. `https://my-resource.communication.azure.com`
  * `:access_key` - Base64-encoded HMAC access key for HMAC-SHA256 authentication (mutually exclusive with `:auth`)
  * `:auth` - Bearer token for Azure RBAC authentication. Can be a string, a 0-arity function, or a `{mod, fun, args}` tuple (mutually exclusive with `:access_key`)

  Exactly one of `:access_key` or `:auth` must be provided.

  ## Example

      # config/config.exs
      config :sample, Sample.Mailer,
        adapter: Swoosh.Adapters.AzureCommunicationServices,
        endpoint: "https://my-resource.communication.azure.com",
        access_key: "base64encodedkey=="

      # lib/sample/mailer.ex
      defmodule Sample.Mailer do
        use Swoosh.Mailer, otp_app: :sample
      end

  ## Using with Bearer token auth

      config :sample, Sample.Mailer,
        adapter: Swoosh.Adapters.AzureCommunicationServices,
        endpoint: "https://my-resource.communication.azure.com",
        auth: fn -> MyApp.TokenProvider.get_token() end

  > #### HMAC Endpoint Matching {: .warning}
  >
  > HMAC signing uses the exact request URI. Configure `:endpoint` as the ACS resource root only.
  > If you get `{"error":{"code":"Denied","message":"Denied by the resource provider."}}`,
  > first check that the configured endpoint matches exactly and does not include a trailing slash
  > or any extra path segments.

  ## Provider Options

    * `:user_engagement_tracking_disabled` (boolean) - Disables user engagement tracking for this email
    * `:operation_id` (string) - A UUID sent as the `Operation-Id` request header for idempotency
    * `:client_request_id` (string) - A client-provided request identifier sent as the `x-ms-client-request-id` request header

  """

  use Swoosh.Adapter, required_config: [:endpoint]

  alias Swoosh.Email

  @api_path "/emails:send"
  @api_version "2025-09-01"

  @impl Swoosh.Adapter
  def deliver(%Email{} = email, config \\ []) do
    validate_auth!(config)

    body = email |> prepare_body() |> Swoosh.json_library().encode!()
    url = api_url(config)
    headers = prepare_headers(body, url, email, config)

    case Swoosh.ApiClient.post(url, headers, body, email) do
      {:ok, 202, response_headers, body} ->
        {:ok, parse_success_response(body, response_headers)}

      {:ok, code, _headers, body} when code >= 400 ->
        case Swoosh.json_library().decode(body) do
          {:ok, parsed} -> {:error, {code, parsed}}
          {:error, _} -> {:error, {code, body}}
        end

      {:ok, code, _headers, body} ->
        {:error, {code, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp validate_auth!(config) do
    ak_missing? = config[:access_key] in [nil, ""]
    au_missing? = config[:auth] in [nil, ""]

    case {ak_missing?, au_missing?} do
      {true, true} ->
        raise ArgumentError,
              "expected exactly one of [:access_key, :auth] to be set in config, got: access_key: missing, auth: missing"

      {false, false} ->
        raise ArgumentError,
              "expected exactly one of [:access_key, :auth] to be set in config, got: both access_key and auth set"

      _ ->
        :ok
    end
  end

  defp api_url(config) do
    "#{config[:endpoint]}#{@api_path}?api-version=#{@api_version}"
  end

  defp prepare_headers(body, url, email, config) do
    base_headers = [
      {"Content-Type", "application/json"},
      {"Accept", "application/json"},
      {"User-Agent", "swoosh/#{Swoosh.version()}"}
    ]

    auth_headers =
      if config[:access_key] do
        hmac_headers(body, url, config[:access_key])
      else
        [{"Authorization", "Bearer #{resolve_auth(config[:auth])}"}]
      end

    base_headers ++ auth_headers ++ request_tracking_headers(email)
  end

  defp hmac_headers(body, url, access_key) do
    uri = URI.parse(url)

    host =
      if uri.port in [80, 443, nil] do
        uri.host
      else
        "#{uri.host}:#{uri.port}"
      end

    path_and_query = path_and_query(uri)

    content_hash = :crypto.hash(:sha256, body) |> Base.encode64()
    timestamp = format_rfc1123(DateTime.utc_now())

    string_to_sign = "POST\n#{path_and_query}\n#{timestamp};#{host};#{content_hash}"

    key = Base.decode64!(access_key)
    signature = :crypto.mac(:hmac, :sha256, key, string_to_sign) |> Base.encode64()

    [
      {"x-ms-date", timestamp},
      {"x-ms-content-sha256", content_hash},
      {"host", host},
      {"Authorization",
       "HMAC-SHA256 SignedHeaders=x-ms-date;host;x-ms-content-sha256&Signature=#{signature}"}
    ]
  end

  defp parse_success_response(body, response_headers) do
    response_headers
    |> response_metadata()
    |> Map.merge(parse_success_body(body))
  end

  defp parse_success_body(body) do
    case Swoosh.json_library().decode(body) do
      {:ok, response} when is_map(response) ->
        %{}
        |> maybe_put(:id, response["id"])
        |> maybe_put(:status, response["status"])

      {:error, _} ->
        %{}
    end
  end

  defp response_metadata(headers) do
    %{}
    |> maybe_put(:operation_location, response_header(headers, "operation-location"))
    |> maybe_put(:retry_after, parse_retry_after(response_header(headers, "retry-after")))
  end

  defp response_header(headers, name) do
    name = String.downcase(name)

    Enum.find_value(headers, fn {header_name, value} ->
      if String.downcase(header_name) == name, do: value
    end)
  end

  defp parse_retry_after(nil), do: nil

  defp parse_retry_after(value) do
    case Integer.parse(value) do
      {seconds, ""} -> seconds
      _ -> value
    end
  end

  defp request_tracking_headers(%{provider_options: provider_options}) do
    []
    |> maybe_put_header("Operation-Id", provider_options[:operation_id])
    |> maybe_put_header("x-ms-client-request-id", provider_options[:client_request_id])
  end

  defp maybe_put_header(headers, _name, nil), do: headers
  defp maybe_put_header(headers, name, value), do: headers ++ [{name, value}]

  defp path_and_query(%URI{path: path, query: nil}), do: path
  defp path_and_query(%URI{path: path, query: query}), do: "#{path}?#{query}"

  defp format_rfc1123(datetime) do
    Calendar.strftime(datetime, "%a, %d %b %Y %H:%M:%S GMT")
  end

  defp resolve_auth(func) when is_function(func, 0), do: func.()
  defp resolve_auth({m, f, a}) when is_atom(m) and is_atom(f) and is_list(a), do: apply(m, f, a)
  defp resolve_auth(token) when is_binary(token), do: token

  defp resolve_auth(_auth) do
    raise ArgumentError,
          "expected :auth to be a string, a 0-arity function, or a {mod, fun, args} tuple"
  end

  defp prepare_body(email) do
    %{}
    |> prepare_sender(email)
    |> prepare_content(email)
    |> prepare_recipients(email)
    |> prepare_reply_to(email)
    |> prepare_attachments(email)
    |> prepare_custom_headers(email)
    |> prepare_provider_options(email)
  end

  defp address_item({"", address}), do: %{"address" => address}
  defp address_item({name, address}), do: %{"address" => address, "displayName" => name}
  defp address_item(address) when is_binary(address), do: %{"address" => address}

  defp prepare_sender(body, %{from: {_name, address}}),
    do: Map.put(body, "senderAddress", address)

  defp prepare_content(body, %{subject: subject, html_body: html, text_body: text}) do
    content =
      %{"subject" => subject}
      |> maybe_put("plainText", text)
      |> maybe_put("html", html)

    Map.put(body, "content", content)
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp prepare_recipients(body, %{to: to, cc: cc, bcc: bcc}) do
    recipients =
      %{"to" => Enum.map(to, &address_item/1)}
      |> maybe_put_recipients("cc", cc)
      |> maybe_put_recipients("bcc", bcc)

    Map.put(body, "recipients", recipients)
  end

  defp maybe_put_recipients(map, _key, []), do: map

  defp maybe_put_recipients(map, key, recipients),
    do: Map.put(map, key, Enum.map(recipients, &address_item/1))

  defp prepare_reply_to(body, %{reply_to: nil}), do: body

  defp prepare_reply_to(body, %{reply_to: reply_to}) when is_list(reply_to),
    do: Map.put(body, "replyTo", Enum.map(reply_to, &address_item/1))

  defp prepare_reply_to(body, %{reply_to: reply_to}),
    do: Map.put(body, "replyTo", [address_item(reply_to)])

  defp prepare_attachments(body, %{attachments: []}), do: body

  defp prepare_attachments(body, %{attachments: attachments}) do
    mapped =
      Enum.map(attachments, fn attachment ->
        item = %{
          "name" => attachment.filename,
          "contentType" => attachment.content_type,
          "contentInBase64" => Swoosh.Attachment.get_content(attachment, :base64)
        }

        case attachment.type do
          :inline -> Map.put(item, "contentId", attachment.cid || attachment.filename)
          :attachment -> item
        end
      end)

    Map.put(body, "attachments", mapped)
  end

  defp prepare_custom_headers(body, %{headers: headers}) when map_size(headers) == 0, do: body

  defp prepare_custom_headers(body, %{headers: headers}),
    do: Map.put(body, "headers", headers)

  defp prepare_provider_options(body, %{provider_options: provider_options}) do
    case Map.get(provider_options, :user_engagement_tracking_disabled) do
      nil -> body
      value -> Map.put(body, "userEngagementTrackingDisabled", value)
    end
  end
end
