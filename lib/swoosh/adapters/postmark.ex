defmodule Swoosh.Adapters.Postmark do
  @moduledoc ~S"""
  An adapter that sends email using the Postmark API.

  For reference: [Postmark API docs](http://developer.postmarkapp.com/developer-send-api.html)

  ## Example

      # config/config.exs
      config :sample, Sample.Mailer,
        adapter: Swoosh.Adapters.Postmark,
        api_key: "my-api-key"

      # lib/sample/mailer.ex
      defmodule Sample.Mailer do
        use Swoosh.Mailer, otp_app: :sample
      end

  ## Example of sending emails using templates

  This will use Postmark's `withTemplate` endpoint.

      import Swoosh.Email

      new()
      |> from({"T Stark", "tony.stark@example.com"})
      |> to({"Steve Rogers", "steve.rogers@example.com"})
      |> put_provider_option(:template_id, "123456")
      |> put_provider_option(:template_model, %{name: "Steve", email: "steve@avengers.com"})

  You can also use `template_alias` instead of `template_id`, if you use Postmark's
  [TemplateAlias](https://postmarkapp.com/developer/api/templates-api#email-with-template)
  feature.

  When sending batch emails using `deliver_many` do not mix emails using templates with
  non-template emails. The use of templates impacts the API endpoint used and so the batch email
  collection should be of the same format.

  ## Example of sending emails with a tag

  This will add a tag to the sent Postmark's email.

      import Swoosh.Email

      new()
      |> from({"T Stark", "tony.stark@example.com"})
      |> to({"Steve Rogers", "steve.rogers@example.com"})
      |> subject("Hello, Avengers!")
      |> put_provider_option(:tag, "some tag")

  ## Provider Options

  - `:metadata` (map)
  - `:tag` (string)
  - `:template_id` (string)
  - `:template_alias` (string)
  - `:template_model` (map)
  """

  use Swoosh.Adapter, required_config: [:api_key]

  alias Swoosh.Email
  import Swoosh.Email.Render

  @base_url "https://api.postmarkapp.com"

  @impl true
  def deliver(%Email{} = email, config \\ []) do
    headers = prepare_headers(config)
    params = email |> prepare_body() |> Swoosh.json_library().encode!
    url = [base_url(config), api_endpoint(email)]

    case Swoosh.ApiClient.post(url, headers, params, email) do
      {:ok, 200, _headers, body} ->
        {:ok, %{id: Swoosh.json_library().decode!(body)["MessageID"]}}

      {:ok, code, _headers, body} when code > 399 ->
        case Swoosh.json_library().decode(body) do
          {:ok, error} -> {:error, {code, error}}
          {:error, _} -> {:error, {code, body}}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl true
  def deliver_many(emails, config \\ [])

  def deliver_many([], _config) do
    {:ok, []}
  end

  @impl true
  def deliver_many(emails, config) when is_list(emails) do
    headers = prepare_headers(config)
    body = emails |> prepare_body() |> Swoosh.json_library().encode!
    url = [base_url(config), api_endpoint(List.first(emails), true)]

    case Swoosh.ApiClient.post(url, headers, body, List.first(emails)) do
      {:ok, 200, _headers, body} ->
        results =
          Enum.map(Swoosh.json_library().decode!(body), fn email_result ->
            %{
              id: email_result["MessageID"],
              error_code: email_result["ErrorCode"],
              message: email_result["Message"]
            }
          end)

        {:ok, results}

      {:ok, code, _headers, body} when code > 399 ->
        case Swoosh.json_library().decode(body) do
          {:ok, error} -> {:error, {code, error}}
          {:error, _} -> {:error, {code, body}}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp base_url(config), do: config[:base_url] || @base_url

  defp prepare_headers(config) do
    [
      {"User-Agent", "swoosh/#{Swoosh.version()}"},
      {"X-Postmark-Server-Token", config[:api_key]},
      {"Content-Type", "application/json"},
      {"Accept", "application/json"}
    ]
  end

  defp api_endpoint(email, batch \\ false) do
    case {email_uses_template?(email), batch} do
      {true, true} -> "/email/batchWithTemplates"
      {true, false} -> "/email/withTemplate"
      {false, true} -> "/email/batch"
      {false, false} -> "/email"
    end
  end

  defp email_uses_template?(%Email{} = email) do
    case email do
      %{provider_options: %{template_id: _, template_model: _}} -> true
      %{provider_options: %{template_alias: _, template_model: _}} -> true
      _ -> false
    end
  end

  defp prepare_body(emails) when is_list(emails) do
    if email_uses_template?(List.first(emails)) do
      %{"Messages" => Enum.map(emails, &prepare_body/1)}
    else
      Enum.map(emails, &prepare_body/1)
    end
  end

  defp prepare_body(email) do
    %{}
    |> prepare_from(email)
    |> prepare_to(email)
    |> prepare_subject(email)
    |> prepare_html(email)
    |> prepare_text(email)
    |> prepare_cc(email)
    |> prepare_bcc(email)
    |> prepare_attachments(email)
    |> prepare_reply_to(email)
    |> prepare_template(email)
    |> prepare_custom_headers(email)
    |> prepare_tag(email)
    |> prepare_metadata(email)
    |> prepare_message_stream(email)
  end

  defp prepare_from(body, %{from: from}), do: Map.put(body, "From", render_recipient(from))

  defp prepare_to(body, %{to: to}), do: Map.put(body, "To", render_recipient(to))

  defp prepare_cc(body, %{cc: []}), do: body
  defp prepare_cc(body, %{cc: cc}), do: Map.put(body, "Cc", render_recipient(cc))

  defp prepare_bcc(body, %{bcc: []}), do: body
  defp prepare_bcc(body, %{bcc: bcc}), do: Map.put(body, "Bcc", render_recipient(bcc))

  defp prepare_attachments(body, %{attachments: []}), do: body

  defp prepare_attachments(body, %{attachments: attachments}) do
    Map.put(body, "Attachments", Enum.map(attachments, &prepare_attachment/1))
  end

  defp prepare_attachment(attachment) do
    attachment_data = %{
      "Name" => attachment.filename,
      "ContentType" => attachment.content_type,
      "Content" => Swoosh.Attachment.get_content(attachment, :base64)
    }

    case attachment.type do
      :attachment ->
        attachment_data

      :inline ->
        Map.put(attachment_data, "ContentID", "cid:#{attachment.filename}")
    end
  end

  defp prepare_reply_to(body, %{reply_to: nil}), do: body

  defp prepare_reply_to(body, %{reply_to: {_name, address}}),
    do: Map.put(body, "ReplyTo", address)

  defp prepare_subject(body, %{subject: ""}), do: body
  defp prepare_subject(body, %{subject: subject}), do: Map.put(body, "Subject", subject)

  defp prepare_text(body, %{text_body: nil}), do: body
  defp prepare_text(body, %{text_body: text_body}), do: Map.put(body, "TextBody", text_body)

  defp prepare_html(body, %{html_body: nil}), do: body
  defp prepare_html(body, %{html_body: html_body}), do: Map.put(body, "HtmlBody", html_body)

  # example custom vars
  #
  # %{
  #   "template_id"    => 123,
  #   "template_model" => %{"name": 1, "company": 2}
  # }
  #
  # Or, using template_alias
  #
  # %{
  #   "template_alias" => "welcome",
  #   "template_model" => %{"name": 1, "company": 2}
  # }
  defp prepare_template(body, %{provider_options: provider_options}),
    do: Enum.reduce(provider_options, body, &put_in_body/2)

  defp prepare_template(body, _email), do: body

  defp put_in_body({:template_model, val}, body_acc), do: Map.put(body_acc, "TemplateModel", val)
  defp put_in_body({:template_id, val}, body_acc), do: Map.put(body_acc, "TemplateId", val)
  defp put_in_body({:template_alias, val}, body_acc), do: Map.put(body_acc, "TemplateAlias", val)
  defp put_in_body(_, body_acc), do: body_acc

  defp prepare_custom_headers(body, %{headers: headers}) when map_size(headers) == 0, do: body

  defp prepare_custom_headers(body, %{headers: headers}) do
    custom_headers = Enum.map(headers, fn {k, v} -> %{"Name" => k, "Value" => v} end)
    Map.put(body, "Headers", custom_headers)
  end

  defp prepare_tag(body, %{provider_options: %{tag: tag_value}}) do
    Map.put(body, "Tag", tag_value)
  end

  defp prepare_tag(body, _), do: body

  defp prepare_metadata(body, %{provider_options: %{metadata: metadata}}) do
    Map.put(body, "Metadata", metadata)
  end

  defp prepare_metadata(body, _), do: body

  defp prepare_message_stream(body, %{provider_options: %{message_stream: value}}),
    do: Map.put(body, "MessageStream", value)

  defp prepare_message_stream(body, _), do: body
end
