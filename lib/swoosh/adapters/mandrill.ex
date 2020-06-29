defmodule Swoosh.Adapters.Mandrill do
  @moduledoc ~S"""
  An adapter that sends email using the Mandrill API.

  It supports both the `send` and `send-template` endpoint. In order to use the
  latter you need to set `template_name` in the `provider_options` map on
  `Swoosh.Email`.

  For reference: [Mandrill API docs](https://mandrillapp.com/api/docs/messages.html)

  ## Example

      # config/config.exs
      config :sample, Sample.Mailer,
        adapter: Swoosh.Adapters.Mandrill,
        api_key: "my-api-key"

      # lib/sample/mailer.ex
      defmodule Sample.Mailer do
        use Swoosh.Mailer, otp_app: :sample
      end

  ## Example of using the `send-template` endpoint

      import Swoosh.Email

      new()
      |> from({"T Stark", "tony.stark@example.com"})
      |> to({"Steve Rogers", "steve.rogers@example.com"})
      |> subject("Hello, Avengers!")
      |> put_provider_option(:template_name, "welcome")
      |> put_provider_option(:template_content, [%{"name" => "START_DATE", "content" => "Next Monday"}])
  """

  use Swoosh.Adapter, required_config: [:api_key]

  alias Swoosh.Email

  @base_url "https://mandrillapp.com/api/1.0"
  @api_endpoint "/messages/send.json"
  @template_api_endpoint "/messages/send-template.json"
  @headers [{"Content-Type", "application/json"}]

  @impl true
  def deliver(%Email{} = email, config \\ []) do
    body = email |> prepare_body(config) |> Swoosh.json_library().encode!
    url = [base_url(config), api_endpoint(email)]

    case Swoosh.ApiClient.post(url, @headers, body, email) do
      {:ok, 200, _headers, body} ->
        parse_response(body)

      {:ok, code, _headers, body} when code > 399 ->
        {:error, {code, Swoosh.json_library().decode!(body)}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp parse_response(body) when is_binary(body),
    do: body |> Swoosh.json_library().decode! |> hd |> parse_response

  defp parse_response(%{"status" => "sent"} = body), do: {:ok, %{id: body["_id"]}}
  defp parse_response(%{"status" => "queued"} = body), do: {:ok, %{id: body["_id"]}}
  defp parse_response(%{"status" => "rejected"} = body), do: {:error, body}
  defp parse_response(body), do: {:error, body}

  defp base_url(config), do: config[:base_url] || @base_url

  defp api_endpoint(%{provider_options: %{template_name: _template_name}}),
    do: @template_api_endpoint

  defp api_endpoint(_email), do: @api_endpoint

  defp prepare_body(email, config) do
    %{message: prepare_message(email)}
    |> set_async(email)
    |> set_template_name(email)
    |> set_template_content(email)
    |> set_api_key(config)
  end

  defp prepare_message(email) do
    %{to: []}
    |> prepare_from(email)
    |> prepare_to(email)
    |> prepare_subject(email)
    |> prepare_html(email)
    |> prepare_text(email)
    |> prepare_cc(email)
    |> prepare_bcc(email)
    |> prepare_attachments(email)
    |> prepare_reply_to(email)
    |> prepare_global_merge_vars(email)
    |> prepare_metadata(email)
    |> prepare_merge_vars(email)
    |> prepare_merge_language(email)
    |> prepare_custom_headers(email)
  end

  defp set_api_key(body, config), do: Map.put(body, :key, config[:api_key])

  defp set_async(body, %{provider_options: %{async: true}}), do: Map.put(body, :async, true)
  defp set_async(body, _email), do: body

  defp prepare_from(body, %{from: {nil, address}}), do: Map.put(body, :from_email, address)

  defp prepare_from(body, %{from: {name, address}}) do
    body
    |> Map.put(:from_name, name)
    |> Map.put(:from_email, address)
  end

  defp prepare_to(body, %{to: to}), do: prepare_recipients(body, to)

  defp prepare_reply_to(body, %{reply_to: nil}), do: body

  defp prepare_reply_to(body, %{reply_to: {_name, address}}) do
    Map.put(body, :headers, %{"Reply-To" => address})
  end

  defp prepare_cc(body, %{cc: []}), do: body
  defp prepare_cc(body, %{cc: cc}), do: prepare_recipients(body, cc, "cc")

  defp prepare_bcc(body, %{bcc: []}), do: body
  defp prepare_bcc(body, %{bcc: bcc}), do: prepare_recipients(body, bcc, "bcc")

  defp prepare_attachments(body, %{attachments: []}), do: body

  defp prepare_attachments(body, %{attachments: attachments}) do
    {normal_attachments, inline_attachments} =
      Enum.split_with(attachments, fn %{type: type} -> type == :attachment end)

    body
    |> Map.put("attachments", prepare_attachments_structure(normal_attachments))
    |> Map.put("images", prepare_attachments_structure(inline_attachments))
  end

  defp prepare_attachments_structure(attachments) do
    Enum.map(attachments, fn attachment ->
      content = Swoosh.Attachment.get_content(attachment, :base64)
      %{type: attachment.content_type, name: attachment.filename, content: content}
    end)
  end

  defp prepare_recipients(body, recipients, type \\ "to") do
    recipients =
      recipients
      |> Enum.map(&prepare_recipient(&1, type))
      |> Enum.concat(body[:to])

    Map.put(body, :to, recipients)
  end

  defp prepare_recipient({"", email}, type), do: %{email: email, type: type}
  defp prepare_recipient({name, email}, type), do: %{email: email, name: name, type: type}

  defp prepare_subject(body, %{subject: subject}), do: Map.put(body, :subject, subject)

  defp prepare_text(body, %{text_body: nil}), do: body
  defp prepare_text(body, %{text_body: text_body}), do: Map.put(body, :text, text_body)

  defp prepare_html(body, %{html_body: nil}), do: body
  defp prepare_html(body, %{html_body: html_body}), do: Map.put(body, :html, html_body)

  defp set_template_name(body, %{provider_options: %{template_name: template_name}}) do
    Map.put(body, :template_name, template_name)
  end

  defp set_template_name(body, _email), do: body

  defp set_template_content(body, %{provider_options: %{template_content: template_content}}) do
    Map.put(body, :template_content, template_content)
  end

  defp set_template_content(body, %{provider_options: %{template_name: _template_name}}) do
    Map.put(body, :template_content, [%{name: "", content: ""}])
  end

  defp set_template_content(body, _email), do: body

  defp prepare_global_merge_vars(body, %{
         provider_options: %{global_merge_vars: global_merge_vars}
       }) do
    Map.put(body, :global_merge_vars, global_merge_vars)
  end

  defp prepare_global_merge_vars(body, _email), do: body

  defp prepare_merge_vars(body, %{provider_options: %{merge_vars: merge_vars}}) do
    Map.put(body, :merge_vars, merge_vars)
  end

  defp prepare_merge_vars(body, _email), do: body

  defp prepare_merge_language(body, %{provider_options: %{merge_language: merge_language}}) do
    Map.put(body, :merge_language, merge_language)
  end

  defp prepare_merge_language(body, _email), do: body

  defp prepare_metadata(body, %{provider_options: %{metadata: metadata}}) do
    Map.put(body, :metadata, metadata)
  end

  defp prepare_metadata(body, _email), do: body

  defp prepare_custom_headers(body, %{headers: headers}) when map_size(headers) == 0, do: body

  defp prepare_custom_headers(body, %{headers: headers}) do
    custom_headers = Map.merge(body[:headers] || %{}, headers)
    Map.put(body, :headers, custom_headers)
  end
end
