defmodule Swoosh.Adapters.ZeptoMail do
  @moduledoc """
  An adapter that sends transactional email using the ZeptoMail API.

  For reference: [ZeptoMail API docs](https://www.zoho.com/zeptomail/help/api/email-sending.html)

  ## Configuration options

  * `:api_key` - the API key without the prefix `Zoho-enczapikey` used with ZeptoMail.
  * `:type` - the type of email to send `:single` or `:batch`. Defaults to `:single`
  * `:base_url` - the url to use as the API endpoint. For EU, use https://api.zeptomail.eu/v1.1

  ## Example

      # config/config.exs
      config :sample, Sample.Mailer,
        adapter: Swoosh.Adapters.ZeptoMail,
        api_key: "my-api-key"

      # lib/sample/mailer.ex
      defmodule Sample.Mailer do
        use Swoosh.Mailer, otp_app: :sample
      end

  ## Using with provider options

      import Swoosh.Email

      new()
      |> from({"T Stark", "tony.stark@example.com"})
      |> to({"Steve Rogers", "steve.rogers@example.com"})
      |> to("wasp.avengers@example.com")
      |> reply_to("office.avengers@example.com")
      |> cc({"Bruce Banner", "hulk.smash@example.com"})
      |> cc("thor.odinson@example.com")
      |> bcc({"Clinton Francis Barton", "hawk.eye@example.com"})
      |> bcc("beast.avengers@example.com")
      |> subject("Hello, Avengers!")
      |> html_body("<h1>Hello</h1><img src=\\"cid:inline-attachment-from-cache\\" />")
      |> text_body("Hello")
      |> put_provider_option(:bounce_address, "bounce@example.com")
      |> put_provider_option(:track_clicks, false)
      |> put_provider_option(:track_opens, true)
      |> put_provider_option(:inline_images, [%{cid: "inline-attachment-from-cache", file_cache_key: "cache-key"}])

  ## Batch Sending

  `ZeptoMail` does not support sending multiple different emails, however it does support sending one email
  to a list of recipients.

  To allow the customization of the email per recipient, a field `:merge_info` may be provided for each recipient.

      import Swoosh.Email

      email =
        new()
        |> from({"T Stark", "tony.stark@example.com"})
        |> to({"Steve Rogers", "steve.rogers@example.com"})
        |> to("wasp.avengers@example.com")
        |> subject("Hello, Avengers!")
        |> html_body("<h1>Hello Avenger from {{ team }}</h1>")
        |> put_provider_option(:merge_info,
          %{
            "steve.rogers@example.com" => %{team: "Avengers"},
            "wasp.avengers@example.com" => %{team: "Avengers 2"}
          }
        )

      Swoosh.Adapters.ZeptoMail.deliver(email, type: :batch)

  ## Provider options
    * `:bounce_address` (string) - The email address to which bounced emails will be sent.

    * `:track_clicks` (boolean) - Enable or disable email click tracking.

    * `:track_opens` (boolean) - Enable or disable email open tracking.

    * `:client_reference` (string) - An identifier set by the user to track a particular transaction.

    * `:mime_headers` (map) - The additional headers to be sent in the email for your reference purposes.

    * `:attachments` (list) - A list of file cache keys to send as attachments.

    * `:inline_images` (list) - A list of map (`cid` and `file_cache_key`) to include as inline attachments.

    * `:template_key` (string) - Unique key identifier of your template.

    * `:template_alias` (string) - Alias name given to the template key, can be used instead of `template_key`.

    * `:merge_info` (map) - Use this values to replace the placeholders in the template.

      In case of batch email sending, this should be a map of email address to a map of key-value.
  """

  use Swoosh.Adapter, required_config: [:api_key]

  alias Swoosh.Email

  @base_url "https://api.zeptomail.com/v1.1"
  @api_endpoint "/email"
  @api_template_endpoint "/email/template"

  defguardp is_template(email)
            when is_map_key(email.provider_options, :template_key) or
                   is_map_key(email.provider_options, :template_alias)

  def deliver(%Email{} = email, config \\ []) do
    type = Keyword.get(config, :type, :single)

    url = base_url(config) <> api_endpoint(email)
    url = if type == :batch, do: url <> "/batch", else: url
    body = type |> prepare_payload(email) |> Swoosh.json_library().encode!()

    headers = [
      {"Accept", "application/json"},
      {"Content-Type", "application/json"},
      {"User-Agent", "swoosh/#{Swoosh.version()}"},
      {"Authorization", "Zoho-enczapikey #{config[:api_key]}"}
    ]

    case Swoosh.ApiClient.post(url, headers, body, email) do
      {:ok, 201, _headers, body} ->
        {:ok, %{id: Swoosh.json_library().decode!(body)["request_id"]}}

      {:ok, code, _headers, body} when code > 399 ->
        reason =
          body
          |> Swoosh.json_library().decode()
          |> case do
            {:ok, decoded} -> decoded
            {:error, _reason} -> body
          end

        {:error, {code, reason}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp base_url(config), do: config[:base_url] || @base_url

  defp api_endpoint(email) when is_template(email), do: @api_template_endpoint
  defp api_endpoint(_email), do: @api_endpoint

  defp prepare_payload(type, email) when is_template(email) do
    email
    |> prepare_common_payload()
    |> prepare_template_key(email)
    |> prepare_merge_info(email, type)
  end

  defp prepare_payload(type, email) do
    body =
      email
      |> prepare_common_payload()
      |> prepare_html(email)
      |> prepare_text(email)
      |> prepare_inline_attachments(email)
      |> prepare_inline_cache_attachments(email)

    if type == :batch, do: prepare_merge_info(body, email, type), else: body
  end

  defp prepare_common_payload(email) do
    %{}
    |> prepare_from(email)
    |> prepare_to(email)
    |> prepare_subject(email)
    |> prepare_cc(email)
    |> prepare_bcc(email)
    |> prepare_reply_to(email)
    |> prepare_attachments(email)
    |> prepare_provider_options(email)
    |> prepare_file_cache_attachments(email)
  end

  defp prepare_from(body, %{from: from}), do: Map.put(body, :from, render_recipient(from))

  defp prepare_to(body, %{to: to}), do: Map.put(body, :to, wrap_recipient(render_recipient(to)))

  defp prepare_subject(body, %{subject: subject}), do: Map.put(body, :subject, subject)

  defp prepare_text(body, %{text_body: nil}), do: body
  defp prepare_text(body, %{text_body: text_body}), do: Map.put(body, :textbody, text_body)

  defp prepare_html(body, %{html_body: nil}), do: body
  defp prepare_html(body, %{html_body: html_body}), do: Map.put(body, :htmlbody, html_body)

  defp prepare_cc(body, %{cc: []}), do: body
  defp prepare_cc(body, %{cc: cc}), do: Map.put(body, :cc, wrap_recipient(render_recipient(cc)))

  defp prepare_bcc(body, %{bcc: []}), do: body

  defp prepare_bcc(body, %{bcc: bcc}) do
    Map.put(body, :bcc, wrap_recipient(render_recipient(bcc)))
  end

  defp prepare_reply_to(body, %{reply_to: reply_to}),
    do: Map.put(body, :reply_to, List.wrap(render_recipient(reply_to)))

  defp prepare_attachments(body, %{attachments: attachments}) do
    attachments = Enum.filter(attachments, &(&1.type == :attachment))
    Map.put(body, :attachments, Enum.map(attachments, &prepare_file(&1)))
  end

  defp prepare_inline_attachments(body, %{attachments: attachments}) do
    inline_attachments = Enum.filter(attachments, &(&1.type == :inline))

    inline_images =
      Enum.map(inline_attachments, fn inline_attachment ->
        inline_attachment
        |> prepare_file()
        |> Map.put(:cid, inline_attachment.cid)
      end)

    Map.put(body, :inline_images, inline_images)
  end

  defp prepare_file(%{data: nil} = attachment) do
    prepare_file(%{attachment | data: File.read!(attachment.path)})
  end

  defp prepare_file(attachment) do
    %{
      mime_type: attachment.content_type,
      name: attachment.filename,
      content: Base.encode64(attachment.data)
    }
  end

  defp prepare_file_cache_attachments(body, %{provider_options: %{attachments: cache_keys}}) do
    attachments = Enum.map(cache_keys, &%{file_cache_key: &1})
    Map.update(body, :attachments, attachments, &Enum.concat(&1, attachments))
  end

  defp prepare_file_cache_attachments(body, _email), do: body

  defp prepare_inline_cache_attachments(body, %{provider_options: %{inline_images: inline_images}}) do
    Map.update(body, :inline_images, inline_images, &Enum.concat(&1, inline_images))
  end

  defp prepare_inline_cache_attachments(body, _email), do: body

  defp prepare_template_key(body, %{provider_options: provider_options}) do
    case Map.fetch(provider_options, :template_key) do
      {:ok, template_key} -> Map.put(body, :template_key, template_key)
      :error -> Map.put(body, :template_alias, provider_options[:template_alias])
    end
  end

  defp prepare_merge_info(body, %{provider_options: provider_options}, :single) do
    Map.put(body, :merge_info, provider_options[:merge_info] || %{})
  end

  defp prepare_merge_info(%{to: recipients} = body, %{provider_options: provider_options}, :batch) do
    merge_info = provider_options[:merge_info] || %{}

    recipients =
      Enum.map(recipients, fn recipient ->
        address = get_in(recipient, [:email_address, :address])
        Map.put(recipient, :merge_info, Map.get(merge_info, address, %{}))
      end)

    %{body | to: recipients}
  end

  defp prepare_provider_options(body, %{provider_options: provider_options}) do
    Map.merge(
      body,
      Map.take(provider_options, [
        :bounce_address,
        :track_opens,
        :track_clicks,
        :mime_headers,
        :client_reference
      ])
    )
  end

  defp wrap_recipient(recipients), do: Enum.map(recipients, &%{email_address: &1})

  defp render_recipient(nil), do: []
  defp render_recipient({name, address}), do: %{address: address, name: name}
  defp render_recipient(list) when is_list(list), do: Enum.map(list, &render_recipient/1)
end
