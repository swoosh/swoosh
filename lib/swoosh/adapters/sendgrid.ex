defmodule Swoosh.Adapters.Sendgrid do
  @provider_options_personalization_fields [
    :custom_args,
    :substitutions,
    :dynamic_template_data
  ]

  @provider_options_body_fields [
    :template_id,
    :asm,
    :categories,
    :mail_settings,
    :tracking_settings,
    :send_at,
    :batch_id
  ]

  @moduledoc ~s"""
  An adapter that sends email using the Sendgrid API.

  For reference: [Sendgrid API docs](https://sendgrid.com/docs/API_Reference/Web_API_v3/Mail/index.html)

  **This adapter requires an API Client.** Swoosh comes with Hackney, Finch and Req out of the box.
  See the [installation section](https://hexdocs.pm/swoosh/Swoosh.html#module-installation)
  for details.

  ## Example

      # config/config.exs
      config :sample, Sample.Mailer,
        adapter: Swoosh.Adapters.Sendgrid,
        api_key: "my-api-key",
        compress: true # default false

      # lib/sample/mailer.ex
      defmodule Sample.Mailer do
        use Swoosh.Mailer, otp_app: :sample
      end

  ## Using with provider options

      import Swoosh.Email

      new()
      |> from({"Xu Shang-Chi", "xu.shangchi@example.com"})
      |> to({"Katy", "katy@example.com"})
      |> reply_to("xu.xialing@example.com")
      |> cc("yingli@example.com")
      |> cc({"Xu Wenwu", "xu.wenwu@example.com"})
      |> bcc("yingnan@example.com")
      |> bcc({"Jon Jon", "jonjon@example.com"})
      |> subject("Hello, Ten Rings!")
      |> html_body("<h1>Hello</h1>")
      |> text_body("Hello")
      |> put_provider_option(:custom_args, %{
        my_var: %{my_message_id: 123},
        my_other_var: %{my_other_id: 1, stuff: 2}
      })
      |> put_provider_option(:asm, %{
        "group_id" => 1,
        "groups_to_display" => [1, 2, 3]
      })
      |> put_provider_option(:categories, ["welcome"])
      |> put_provider_option(:mail_settings, %{
        sandbox_mode: %{enable: true}
      })
      |> put_provider_option(:tracking_settings, %{
        subscription_tracking: %{enable: false}
      })
      |> put_provider_option(:batch_id, "AsdFgHjklQweRTYuIopzXcVBNm0aSDfGHjklmZcVbNMqWert1znmOP2asDFjkl")
      |> put_provider_option(:send_at, 1617260400)

  ## Provider Options

  Supported provider options are the following:

  #### Inserted into personalization

    * `:custom_args` (map) - key/value pairs custom arguments that specific to
      this personalization

    * `:substitutions` (map) - key/value pairs of substitutions string applied
      to the `:subject` and `:reply-to` parameter

    * `:dynamic_template_data` (map) - key/value pairs of dynamic template data
      used in Dynamic Transactional Templates, see `:template_id`

  #### Inserted into request body

    * `:template_id` (string) - an email template ID

    * `:asm` (map) - a map contains fields below on how to handle unsubscribes

    * `:categories` (list[string]) - list of category name for this message

    * `:mail_settings` (map) - collection of mail settings to handle this email

    * `:tracking_settings` (map) - collection of settings to track the metrics
      of responses of email recipients

    * `:send_at` (integer) - A unix timestamp allowing you to specify when
      you want your email to be delivered.

    * `:batch_id` (string) - An ID representing a batch of emails to be sent at
      the same time. It also enables you to cancel or pause the delivery of that batch

  ## Sandbox mode

  For [sandbox mode](https://sendgrid.com/docs/for-developers/sending-email/sandbox-mode/), use `put_provider_option/3`:

      iex> new() |> put_provider_option(:mail_settings, %{sandbox_mode: %{enable: true}})

  """

  use Swoosh.Adapter, required_config: [:api_key]

  alias Swoosh.Email

  @base_url "https://api.sendgrid.com/v3"
  @api_endpoint "/mail/send"

  def deliver(%Email{} = email, config \\ []) do
    headers =
      [
        {"Content-Type", "application/json"},
        {"Accept", "application/json"},
        {"User-Agent", "swoosh/#{Swoosh.version()}"},
        {"Authorization", "Bearer #{config[:api_key]}"}
      ]
      |> maybe_set_content_encoding(config[:compress])

    body =
      email
      |> prepare_body()
      |> Swoosh.json_library().encode!
      |> maybe_compress_body(config[:compress])

    url = [base_url(config), @api_endpoint]

    case Swoosh.ApiClient.post(url, headers, body, email) do
      {:ok, code, headers, _body} when code >= 200 and code <= 399 ->
        {:ok, %{id: extract_id(headers)}}

      {:ok, code, _headers, body} when code >= 400 ->
        case Swoosh.json_library().decode(body) do
          {:ok, error} -> {:error, {code, error}}
          {:error, _} -> {:error, {code, body}}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp maybe_set_content_encoding(headers, _compress = true),
    do: headers ++ [{"Content-Encoding", "gzip"}]

  defp maybe_set_content_encoding(headers, _), do: headers

  defp maybe_compress_body(body, _compress = true), do: :zlib.gzip(body)
  defp maybe_compress_body(body, _), do: body

  defp extract_id(headers) do
    headers
    |> Enum.map(fn {k, v} -> {String.downcase(k), v} end)
    |> Enum.into(%{})
    |> Map.get("x-message-id")
  end

  defp base_url(config), do: config[:base_url] || @base_url

  defp prepare_body(email) do
    %{}
    |> prepare_from(email)
    |> prepare_personalizations(email)
    |> prepare_subject(email)
    |> prepare_content(email)
    |> prepare_attachments(email)
    |> prepare_reply_to(email)
    |> prepare_custom_headers(email)
    |> prepare_provider_options_body_fields(email)
  end

  defp email_item({"", email}), do: %{email: email}
  defp email_item({name, email}), do: %{email: email, name: name}
  defp email_item(email), do: %{email: email}

  defp prepare_from(body, %{from: from}),
    do: Map.put(body, :from, from |> email_item)

  defp prepare_personalizations(body, %{provider_options: %{personalizations: personalizations}})
       when is_list(personalizations) do
    Map.put(body, :personalizations, personalizations)
  end

  defp prepare_personalizations(body, email) do
    personalizations =
      %{}
      |> prepare_to(email)
      |> prepare_cc(email)
      |> prepare_bcc(email)
      |> prepare_provider_options_personalization_fields(email)

    Map.put(body, :personalizations, [personalizations])
  end

  defp prepare_to(personalizations, %{to: to}),
    do: Map.put(personalizations, :to, to |> Enum.map(&email_item(&1)))

  defp prepare_cc(personalizations, %{cc: []}), do: personalizations

  defp prepare_cc(personalizations, %{cc: cc}),
    do: Map.put(personalizations, :cc, cc |> Enum.map(&email_item(&1)))

  defp prepare_bcc(personalizations, %{bcc: []}), do: personalizations

  defp prepare_bcc(personalizations, %{bcc: bcc}),
    do: Map.put(personalizations, :bcc, bcc |> Enum.map(&email_item(&1)))

  defp prepare_subject(body, %{subject: subject}),
    do: Map.put(body, :subject, subject)

  defp prepare_content(body, %{html_body: html, text_body: text}) do
    content =
      Enum.reject(
        [%{type: "text/plain", value: text}, %{type: "text/html", value: html}],
        &is_nil(&1.value)
      )

    case content do
      [] -> body
      _ -> Map.put(body, :content, content)
    end
  end

  defp prepare_attachments(body, %{attachments: []}), do: body

  defp prepare_attachments(body, %{attachments: attachments}) do
    attachments =
      Enum.map(attachments, fn attachment ->
        attachment_info = %{
          filename: attachment.filename,
          type: attachment.content_type,
          content: Swoosh.Attachment.get_content(attachment, :base64)
        }

        extra =
          case attachment.type do
            :inline -> %{disposition: "inline", content_id: attachment.filename}
            :attachment -> %{disposition: "attachment"}
          end

        Map.merge(attachment_info, extra)
      end)

    Map.put(body, :attachments, attachments)
  end

  defp prepare_reply_to(body, %{reply_to: nil}), do: body

  defp prepare_reply_to(body, %{reply_to: reply_to}) when is_list(reply_to),
    do: Map.put(body, :reply_to_list, reply_to |> Enum.uniq() |> Enum.map(&email_item/1))

  defp prepare_reply_to(body, %{reply_to: reply_to}),
    do: Map.put(body, :reply_to, email_item(reply_to))

  defp prepare_custom_headers(body, %{headers: headers})
       when map_size(headers) == 0,
       do: body

  defp prepare_custom_headers(body, %{headers: headers}) do
    Map.put(body, :headers, headers)
  end

  defp prepare_provider_options_personalization_fields(personalization, %{
         provider_options: provider_options
       }) do
    Map.merge(
      personalization,
      Map.take(provider_options, @provider_options_personalization_fields)
    )
  end

  defp prepare_provider_options_body_fields(body, %{provider_options: provider_options}) do
    Map.merge(body, Map.take(provider_options, @provider_options_body_fields))
  end
end
