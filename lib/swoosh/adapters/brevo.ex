defmodule Swoosh.Adapters.Brevo do
  @moduledoc ~S"""
  An adapter that sends email using the Brevo API (Transactional emails only).

  For reference: [Brevo API docs](https://developers.brevo.com/reference/sendtransacemail)

  **This adapter requires an API Client.** Swoosh comes with Hackney, Finch and Req out of the box.
  See the [installation section](https://hexdocs.pm/swoosh/Swoosh.html#module-installation)
  for details.

  ## Example

      # config/config.exs
      config :sample, Sample.Mailer,
        adapter: Swoosh.Adapters.Brevo,
        api_key: "my-api-key"

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
      |> put_provider_option(:id, 42)
      |> put_provider_option(:template_id, 42)
      |> put_provider_option(:params, %{param1: "a", param2: 123})
      |> put_provider_option(:tags, ["tag_1", "tag_2"])
      |> put_provider_option(:schedule_at, ~U[2022-11-15 11:00:00Z])

  ## Provider Options

    * `sender_id` (integer) - `sender`, the sender `id` where this library will
      add email obtained from the `from/1`

    * `template_id` (integer) - `templateId`, the Id of the `active`
      transactional email template

    * `params` (map) - `params`, a map of key/value attributes to customize the
      template

    * `tags` (list[string]) - `tags`, a list of tags for each email for easy
      filtering

    * `schedule_at` (UTC DateTime) - `schedule_at`, a UTC date-time on which the email has to schedule

  """

  use Swoosh.Adapter, required_config: [:api_key]

  alias Swoosh.Email

  @base_url "https://api.brevo.com/v3"
  @api_endpoint "/smtp/email"

  defp base_url(config), do: config[:base_url] || @base_url

  def deliver(%Email{} = email, config \\ []) do
    headers = [
      {"Accept", "application/json"},
      {"Content-Type", "application/json"},
      {"User-Agent", "swoosh/#{Swoosh.version()}"},
      {"Api-Key", config[:api_key]}
    ]

    body = email |> prepare_payload() |> Swoosh.json_library().encode!
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

  defp extract_message_id(body) do
    body
    |> Swoosh.json_library().decode!()
    |> Map.get("messageId")
  end

  defp prepare_payload(email) do
    %{}
    |> prepare_from(email)
    |> prepare_reply_to(email)
    |> prepare_to(email)
    |> prepare_cc(email)
    |> prepare_bcc(email)
    |> prepare_subject(email)
    |> prepare_text_content(email)
    |> prepare_html_content(email)
    |> prepare_template_id(email)
    |> prepare_headers(email)
    |> prepare_params(email)
    |> prepare_tags(email)
    |> prepare_attachments(email)
    |> prepare_schedule_at(email)
  end

  defp prepare_from(payload, %{from: {_name, email}, provider_options: %{sender_id: sender_id}}),
    do: Map.put(payload, "sender", %{id: sender_id, email: email})

  defp prepare_from(payload, %{from: {_, "TEMPLATE"}}), do: payload

  defp prepare_from(payload, %{from: from}),
    do: Map.put(payload, "sender", prepare_recipient(from))

  defp prepare_reply_to(payload, %{reply_to: nil}),
    do: payload

  defp prepare_reply_to(payload, %{reply_to: reply_to}),
    do: Map.put(payload, "replyTo", prepare_recipient(reply_to))

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
    Map.put(payload, "textContent", text_content)
  end

  defp prepare_html_content(payload, %{html_body: nil}), do: payload

  defp prepare_html_content(payload, %{html_body: html_content}) do
    Map.put(payload, "htmlContent", html_content)
  end

  defp prepare_template_id(payload, %{provider_options: %{template_id: template_id}}) do
    Map.put(payload, "templateId", template_id)
  end

  defp prepare_template_id(payload, _), do: payload

  defp prepare_headers(payload, %{headers: map}) when map_size(map) == 0, do: payload

  defp prepare_headers(payload, %{headers: headers}) do
    Map.put(payload, "headers", headers)
  end

  defp prepare_params(payload, %{provider_options: %{params: params}}) when is_map(params) do
    Map.put(payload, "params", params)
  end

  defp prepare_params(payload, _), do: payload

  defp prepare_tags(payload, %{provider_options: %{tags: tags}}) when is_list(tags) do
    Map.put(payload, "tags", tags)
  end

  defp prepare_tags(payload, _), do: payload

  defp prepare_attachments(payload, %{attachments: []}), do: payload

  defp prepare_attachments(payload, %{attachments: attachments}) do
    Map.put(
      payload,
      "attachment",
      Enum.map(
        attachments,
        &%{
          name: &1.filename,
          content: Swoosh.Attachment.get_content(&1, :base64)
        }
      )
    )
  end

  defp prepare_schedule_at(payload, %{provider_options: %{schedule_at: schedule_at}}) do
    Map.put(payload, "scheduledAt", schedule_at)
  end

  defp prepare_schedule_at(payload, _), do: payload

  defp prepare_recipient({name, email}) when name in [nil, ""],
    do: %{email: email}

  defp prepare_recipient({name, email}),
    do: %{name: name, email: email}
end
