defmodule Swoosh.Adapters.Scaleway do
  @moduledoc ~S"""
  An adapter that sends email using the Scaleway API (Transactional emails only).

  For reference: [Scaleway API docs](https://www.scaleway.com/en/developers/api/transactional-email/#path-emails-send-an-email)

  **This adapter requires an API Client.** Swoosh comes with Hackney, Finch and Req out of the box.
  See the [installation section](https://hexdocs.pm/swoosh/Swoosh.html#module-installation)
  for details.

  ## Example

      # config/config.exs
      config :sample, Sample.Mailer,
        adapter: Swoosh.Adapters.Scaleway,
        project_id: "my-project-id",
        secret_key: "my-api-key"

      # lib/sample/mailer.ex
      defmodule Sample.Mailer do
        use Swoosh.Mailer, otp_app: :sample
      end

  ## Using with provider options

      import Swoosh.Email

      new()
      |> from("nora@example.com")
      |> to("shushu@example.com")
      |> subject("Hello, Wally!")
      |> text_body("Hello")
      |> put_provider_option(:send_before, ~U[2022-11-15 11:00:00Z])

  ## Provider Options

    * `send_before` (RFC 3339 format) - `send_before`, maximum date to deliver the email.

  """

  use Swoosh.Adapter, required_config: [:project_id, :secret_key]

  alias Swoosh.Email

  @base_url "https://api.scaleway.com/transactional-email/v1alpha1/regions/fr-par"
  @api_endpoint "/emails"

  defp base_url(config), do: config[:base_url] || @base_url

  def deliver(%Email{} = email, config \\ []) do
    headers = prepare_headers(config)
    body = email |> prepare_payload(config[:project_id]) |> Swoosh.json_library().encode!
    url = [base_url(config), @api_endpoint]

    case Swoosh.ApiClient.post(url, headers, body, email) do
      {:ok, code, _headers, body} when code >= 200 and code <= 399 ->
        {:ok, %{id: extract_message_id(body)}}

      {:ok, code, _headers, body} when code >= 400 ->
        case Swoosh.json_library().decode(body) do
          {:ok, error} -> {:error, {code, error}}
          {:error, _} -> {:error, {code, body}}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp prepare_headers(config) do
    [
      {"Accept", "application/json"},
      {"Content-Type", "application/json"},
      {"User-Agent", "swoosh/#{Swoosh.version()}"},
      {"X-Auth-Token", config[:secret_key]}
    ]
  end

  defp extract_message_id(body) do
    body
    |> Swoosh.json_library().decode!()
    |> Map.get("emails")
    |> hd()
    |> Map.get("message_id")
  end

  defp prepare_payload(email, project_id) do
    %{}
    |> prepare_project_id(project_id)
    |> prepare_from(email)
    |> prepare_reply_to(email)
    |> prepare_to(email)
    |> prepare_cc(email)
    |> prepare_bcc(email)
    |> prepare_subject(email)
    |> prepare_text_content(email)
    |> prepare_html_content(email)
    |> prepare_headers(email)
    |> prepare_params(email)
    |> prepare_attachments(email)
    |> prepare_send_before(email)
  end

  defp prepare_project_id(payload, project_id), do: Map.put(payload, "project_id", project_id)

  defp prepare_from(payload, %{from: from}), do: Map.put(payload, "from", prepare_recipient(from))

  defp prepare_reply_to(payload, _reply_to), do: payload

  defp prepare_to(payload, %{to: to}) do
    Map.put(payload, "to", Enum.map(to, &prepare_recipient/1))
  end

  defp prepare_cc(payload, %{cc: []}), do: payload

  defp prepare_cc(payload, %{cc: cc}) do
    Map.put(payload, "cc", Enum.map(cc, &prepare_recipient/1))
  end

  defp prepare_bcc(payload, %{bcc: []}), do: payload

  defp prepare_bcc(payload, %{bcc: bcc}) do
    Map.put(payload, "bcc", Enum.map(bcc, &prepare_recipient/1))
  end

  defp prepare_subject(payload, %{subject: ""}), do: payload

  defp prepare_subject(payload, %{subject: subject}),
    do: Map.put(payload, "subject", subject)

  defp prepare_subject(payload, _), do: payload

  defp prepare_text_content(payload, %{text_body: nil}), do: payload

  defp prepare_text_content(payload, %{text_body: text_content}) do
    Map.put(payload, "text", text_content)
  end

  defp prepare_html_content(payload, %{html_body: nil}), do: payload

  defp prepare_html_content(payload, %{html_body: html_content}) do
    Map.put(payload, "html", html_content)
  end

  defp prepare_headers(payload, %{headers: map}) when map_size(map) == 0, do: payload

  defp prepare_headers(payload, %{headers: headers}) do
    Map.put(payload, "headers", headers)
  end

  defp prepare_params(payload, %{provider_options: %{params: params}}) when is_map(params) do
    Map.put(payload, "params", params)
  end

  defp prepare_params(payload, _), do: payload

  defp prepare_attachments(payload, %{attachments: []}), do: payload

  defp prepare_attachments(payload, %{attachments: attachments}) do
    Map.put(
      payload,
      "attachments",
      Enum.map(
        attachments,
        &%{
          name: &1.filename,
          content: Swoosh.Attachment.get_content(&1, :base64)
        }
      )
    )
  end

  defp prepare_recipient({name, email}) when name in [nil, ""],
    do: %{email: email}

  defp prepare_recipient({name, email}),
    do: %{name: name, email: email}

  defp prepare_send_before(payload, %{provider_options: %{send_before: send_before}}) do
    Map.put(payload, "send_before", send_before)
  end

  defp prepare_send_before(payload, _), do: payload
end
