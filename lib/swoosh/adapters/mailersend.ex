defmodule Swoosh.Adapters.Mailersend do
  @moduledoc ~S"""
  An adapter that sends email using the MailerSend API.

  For reference: [MailerSend API docs](https://developers.mailersend.com/api/v1/email.html)

  **This adapter requires an API Client.** Swoosh comes with Hackney, Finch and Req out of the box.
  See the [installation section](https://hexdocs.pm/swoosh/Swoosh.html#module-installation)
  for details.

  ## Example

      # config/config.exs
      config :sample, Sample.Mailer,
        adapter: Swoosh.Adapters.Mailersend,
        api_key: "your-api-key"

      # lib/sample/mailer.ex
      defmodule Sample.Mailer do
        use Swoosh.Mailer, otp_app: :sample
      end

  ## Using with provider options

      import Swoosh.Email

      new()
      |> from({"T Stark", "tony.stark@example.com"})
      |> to({"Steve Rogers", "steve.rogers@example.com"})
      |> subject("Hello, Avengers!")
      |> html_body("<h1>Hello</h1>")
      |> text_body("Hello")
      |> put_provider_option(:tags, ["onboarding", "welcome"])
      |> put_provider_option(:track_opens, true)
      |> put_provider_option(:track_clicks, true)
      |> put_provider_option(:metadata, %{"user_id" => "123"})

  ## Using with MailerSend templates

      import Swoosh.Email

      new()
      |> from({"T Stark", "tony.stark@example.com"})
      |> to({"Steve Rogers", "steve.rogers@example.com"})
      |> put_provider_option(:template_id, "template-123")
      |> put_provider_option(:template_variables, %{
        "name" => "Steve",
        "mission" => "Project Insight"
      })

  ## Personalization without templates

  MailerSend supports `{{ variable }}` substitution in subject, HTML, and
  text body fields without requiring a template.

      import Swoosh.Email

      new()
      |> from({"T Stark", "tony.stark@example.com"})
      |> to({"Steve Rogers", "steve.rogers@example.com"})
      |> subject("Welcome {{ name }}!")
      |> html_body("<h1>Hello {{ name }}</h1>")
      |> put_provider_option(:personalization, [
        %{"email" => "steve.rogers@example.com", "data" => %{"name" => "Steve"}}
      ])

  ## Provider Options

    * `:template_id` (string) - MailerSend template ID to use instead of
      html/text body

    * `:template_variables` (map) - variables for template personalization,
      applied to all recipients via the `personalization` array

    * `:personalization` (list of maps) - per-recipient personalization data
      for non-template emails. Each map must have `"email"` and `"data"` keys.
      Values populate `{{ variable }}` placeholders in subject, HTML, and text

    * `:tags` (list of strings) - tags to categorize the email (max 5)

    * `:webhook_id` (string) - webhook ID for delivery tracking

    * `:metadata` (map) - custom metadata to attach to the email

    * `:send_at` (integer or DateTime) - unix timestamp or DateTime for
      scheduled sending

    * `:track_opens` (boolean) - enable open tracking

    * `:track_clicks` (boolean) - enable click tracking

    * `:track_content` (boolean) - enable content tracking

    * `:in_reply_to` (string) - Message-ID of the email being replied to

    * `:references` (list of strings) - list of Message-IDs that the
      current email is referencing

    * `:precedence_bulk` (boolean) - set precedence bulk header, overrides
      domain's advanced settings

    * `:list_unsubscribe` (string) - List-Unsubscribe header value per
      RFC 8058
  """

  use Swoosh.Adapter, required_config: [:api_key]

  alias Swoosh.Email

  @base_url "https://api.mailersend.com"
  @api_endpoint "/v1/email"
  @bulk_endpoint "/v1/bulk-email"

  def deliver(%Email{} = email, config \\ []) do
    headers = prepare_headers(config)
    url = [base_url(config), @api_endpoint]
    body = email |> prepare_body() |> Swoosh.json_library().encode!()

    case Swoosh.ApiClient.post(url, headers, body, email) do
      {:ok, 202, response_headers, response_body} ->
        id = get_header_value(response_headers, "x-message-id")

        case Swoosh.json_library().decode(response_body) do
          {:ok, %{"warnings" => warnings}} when is_list(warnings) ->
            {:ok, %{id: id, warnings: warnings}}

          _ ->
            {:ok, %{id: id}}
        end

      {:ok, code, _headers, body} when code > 399 ->
        case Swoosh.json_library().decode(body) do
          {:ok, error} -> {:error, {code, error}}
          {:error, _} -> {:error, {code, body}}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  def deliver_many(emails, config \\ [])
  def deliver_many([], _config), do: {:ok, []}

  def deliver_many(emails, config) when is_list(emails) do
    headers = prepare_headers(config)
    body = emails |> Enum.map(&prepare_body/1) |> Swoosh.json_library().encode!()
    url = [base_url(config), @bulk_endpoint]

    case Swoosh.ApiClient.post(url, headers, body, List.first(emails)) do
      {:ok, 202, _headers, body} ->
        {:ok, %{bulk_email_id: extract_bulk_id(body)}}

      {:ok, code, _headers, body} when code > 399 ->
        case Swoosh.json_library().decode(body) do
          {:ok, error} -> {:error, {code, error}}
          {:error, _} -> {:error, {code, body}}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp extract_bulk_id(body) do
    body |> Swoosh.json_library().decode!() |> Map.get("bulk_email_id")
  end

  defp base_url(config), do: config[:base_url] || @base_url

  defp prepare_headers(config) do
    [
      {"User-Agent", "swoosh/#{Swoosh.version()}"},
      {"Authorization", "Bearer #{config[:api_key]}"},
      {"Content-Type", "application/json"},
      {"Accept", "application/json"},
      {"X-Requested-With", "XMLHttpRequest"}
    ]
  end

  defp prepare_body(%Email{provider_options: %{template_id: template_id}} = email) do
    %{}
    |> Map.put("template_id", template_id)
    |> prepare_from(email)
    |> prepare_to(email)
    |> prepare_cc(email)
    |> prepare_bcc(email)
    |> prepare_subject_if_present(email)
    |> prepare_reply_to(email)
    |> prepare_attachments(email)
    |> prepare_custom_headers(email)
    |> prepare_template_personalization(email)
    |> prepare_tags(email)
    |> prepare_webhook_id(email)
    |> prepare_metadata(email)
    |> prepare_send_at(email)
    |> prepare_tracking(email)
    |> prepare_in_reply_to(email)
    |> prepare_references(email)
    |> prepare_precedence_bulk(email)
    |> prepare_list_unsubscribe(email)
  end

  defp prepare_body(email) do
    %{}
    |> prepare_from(email)
    |> prepare_to(email)
    |> prepare_cc(email)
    |> prepare_bcc(email)
    |> prepare_subject(email)
    |> prepare_html(email)
    |> prepare_text(email)
    |> prepare_reply_to(email)
    |> prepare_attachments(email)
    |> prepare_custom_headers(email)
    |> prepare_personalization(email)
    |> prepare_tags(email)
    |> prepare_webhook_id(email)
    |> prepare_metadata(email)
    |> prepare_send_at(email)
    |> prepare_tracking(email)
    |> prepare_in_reply_to(email)
    |> prepare_references(email)
    |> prepare_precedence_bulk(email)
    |> prepare_list_unsubscribe(email)
  end

  defp prepare_from(body, %{from: nil}), do: body
  defp prepare_from(body, %{from: from}), do: Map.put(body, "from", render_recipient(from))

  defp prepare_to(body, %{to: []}), do: body
  defp prepare_to(body, %{to: to}), do: Map.put(body, "to", Enum.map(to, &render_recipient/1))

  defp prepare_cc(body, %{cc: []}), do: body
  defp prepare_cc(body, %{cc: cc}), do: Map.put(body, "cc", Enum.map(cc, &render_recipient/1))

  defp prepare_bcc(body, %{bcc: []}), do: body

  defp prepare_bcc(body, %{bcc: bcc}),
    do: Map.put(body, "bcc", Enum.map(bcc, &render_recipient/1))

  defp prepare_subject(body, %{subject: nil}), do: body
  defp prepare_subject(body, %{subject: subject}), do: Map.put(body, "subject", subject)

  defp prepare_subject_if_present(body, %{subject: nil}), do: body
  defp prepare_subject_if_present(body, %{subject: ""}), do: body

  defp prepare_subject_if_present(body, %{subject: subject}),
    do: Map.put(body, "subject", subject)

  defp prepare_html(body, %{html_body: nil}), do: body
  defp prepare_html(body, %{html_body: html_body}), do: Map.put(body, "html", html_body)

  defp prepare_text(body, %{text_body: nil}), do: body
  defp prepare_text(body, %{text_body: text_body}), do: Map.put(body, "text", text_body)

  defp prepare_reply_to(body, %{reply_to: nil}), do: body

  defp prepare_reply_to(body, %{reply_to: reply_to}),
    do: Map.put(body, "reply_to", render_recipient(reply_to))

  defp prepare_attachments(body, %{attachments: []}), do: body

  defp prepare_attachments(body, %{attachments: attachments}) do
    sorted =
      Enum.sort_by(attachments, fn
        %{type: :inline} -> 1
        _ -> 0
      end)

    Map.put(body, "attachments", Enum.map(sorted, &prepare_attachment/1))
  end

  defp prepare_attachment(attachment) do
    base = %{
      "content" => Swoosh.Attachment.get_content(attachment, :base64),
      "filename" => attachment.filename,
      "type" => attachment.content_type
    }

    case attachment.type do
      :inline ->
        base
        |> Map.put("disposition", "inline")
        |> put_attachment_id(attachment.cid)

      _ ->
        Map.put(base, "disposition", "attachment")
    end
  end

  defp put_attachment_id(att, cid) when is_binary(cid), do: Map.put(att, "id", cid)
  defp put_attachment_id(att, _), do: att

  defp prepare_custom_headers(body, %{headers: headers}) when map_size(headers) == 0, do: body

  defp prepare_custom_headers(body, %{headers: headers}) do
    formatted = Enum.map(headers, fn {name, value} -> %{"name" => name, "value" => value} end)
    Map.put(body, "headers", formatted)
  end

  # Template personalization: applies template_variables to all recipients
  defp prepare_template_personalization(body, %{
         to: to,
         cc: cc,
         bcc: bcc,
         provider_options: provider_options
       }) do
    case Map.get(provider_options, :template_variables) do
      nil ->
        body

      variables when is_map(variables) ->
        all_recipients = to ++ cc ++ bcc

        personalization =
          Enum.map(all_recipients, fn recipient ->
            %{
              "email" => recipient_email(recipient),
              "data" => variables
            }
          end)

        Map.put(body, "personalization", personalization)
    end
  end

  # Non-template personalization: user provides per-recipient data directly
  defp prepare_personalization(body, %{provider_options: %{personalization: personalization}})
       when is_list(personalization) do
    Map.put(body, "personalization", personalization)
  end

  defp prepare_personalization(body, _email), do: body

  defp prepare_tags(body, %{provider_options: %{tags: tags}}) when is_list(tags),
    do: Map.put(body, "tags", tags)

  defp prepare_tags(body, _), do: body

  defp prepare_webhook_id(body, %{provider_options: %{webhook_id: id}}),
    do: Map.put(body, "webhook_id", id)

  defp prepare_webhook_id(body, _), do: body

  defp prepare_metadata(body, %{provider_options: %{metadata: metadata}}) when is_map(metadata),
    do: Map.put(body, "metadata", metadata)

  defp prepare_metadata(body, _), do: body

  defp prepare_send_at(body, %{provider_options: %{send_at: %DateTime{} = dt}}),
    do: Map.put(body, "send_at", DateTime.to_unix(dt))

  defp prepare_send_at(body, %{provider_options: %{send_at: ts}}) when is_integer(ts),
    do: Map.put(body, "send_at", ts)

  defp prepare_send_at(body, _), do: body

  defp prepare_tracking(body, %{provider_options: provider_options}) do
    settings =
      %{}
      |> put_if_boolean("track_opens", Map.get(provider_options, :track_opens))
      |> put_if_boolean("track_clicks", Map.get(provider_options, :track_clicks))
      |> put_if_boolean("track_content", Map.get(provider_options, :track_content))

    case map_size(settings) do
      0 -> body
      _ -> Map.put(body, "settings", settings)
    end
  end

  defp prepare_tracking(body, _), do: body

  defp prepare_in_reply_to(body, %{provider_options: %{in_reply_to: value}})
       when is_binary(value),
       do: Map.put(body, "in_reply_to", value)

  defp prepare_in_reply_to(body, _), do: body

  defp prepare_references(body, %{provider_options: %{references: refs}}) when is_list(refs),
    do: Map.put(body, "references", refs)

  defp prepare_references(body, _), do: body

  defp prepare_precedence_bulk(body, %{provider_options: %{precedence_bulk: value}})
       when is_boolean(value),
       do: Map.put(body, "precedence_bulk", value)

  defp prepare_precedence_bulk(body, _), do: body

  defp prepare_list_unsubscribe(body, %{provider_options: %{list_unsubscribe: value}})
       when is_binary(value),
       do: Map.put(body, "list_unsubscribe", value)

  defp prepare_list_unsubscribe(body, _), do: body

  defp put_if_boolean(map, _key, nil), do: map
  defp put_if_boolean(map, key, value) when is_boolean(value), do: Map.put(map, key, value)
  defp put_if_boolean(map, _key, _), do: map

  defp render_recipient({name, email}) when is_binary(name) and name != "",
    do: %{"email" => email, "name" => name}

  defp render_recipient({_name, email}), do: %{"email" => email}
  defp render_recipient(email) when is_binary(email), do: %{"email" => email}

  defp recipient_email({_name, email}), do: email
  defp recipient_email(email) when is_binary(email), do: email

  defp get_header_value(headers, key) do
    key_down = String.downcase(key)

    Enum.find_value(headers, fn {k, v} ->
      if String.downcase(k) == key_down, do: v
    end)
  end
end
