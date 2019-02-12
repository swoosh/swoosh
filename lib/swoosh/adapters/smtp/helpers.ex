defmodule Swoosh.Adapters.SMTP.Helpers do
  @moduledoc false

  alias Swoosh.Email

  import Swoosh.Email.Render

  @doc false
  def sender(%Email{} = email) do
    email.headers["Sender"] || elem(email.from, 1)
  end

  @doc false
  def body(email, config) do
    {message_config, config} = Keyword.split(config, [:transfer_encoding])
    {type, subtype, headers, parts} = prepare_message(email, message_config)
    {encoding_config, _config} = Keyword.split(config, [:dkim])
    :mimemail.encode({type, subtype, headers, [], parts}, encoding_config)
  end

  @doc false
  def prepare_message(email, config) do
    email
    |> prepare_headers()
    |> prepare_parts(email, config)
  end

  defp prepare_headers(email) do
    []
    |> prepare_additional_headers(email)
    |> prepare_mime_version
    |> prepare_reply_to(email)
    |> prepare_subject(email)
    |> prepare_bcc(email)
    |> prepare_cc(email)
    |> prepare_to(email)
    |> prepare_from(email)
  end

  defp prepare_subject(headers, %{subject: subject}), do: [{"Subject", subject} | headers]

  defp prepare_from(headers, %{from: from}), do: [{"From", render_recipient(from)} | headers]

  defp prepare_to(headers, %{to: to}), do: [{"To", render_recipient(to)} | headers]

  defp prepare_cc(headers, %{cc: []}), do: headers
  defp prepare_cc(headers, %{cc: cc}), do: [{"Cc", render_recipient(cc)} | headers]

  defp prepare_bcc(headers, %{bcc: []}), do: headers
  defp prepare_bcc(headers, %{bcc: bcc}), do: [{"Bcc", render_recipient(bcc)} | headers]

  defp prepare_reply_to(headers, %{reply_to: nil}), do: headers

  defp prepare_reply_to(headers, %{reply_to: reply_to}),
    do: [{"Reply-To", render_recipient(reply_to)} | headers]

  defp prepare_mime_version(headers), do: [{"Mime-Version", "1.0"} | headers]

  defp prepare_additional_headers(headers, %{headers: additional_headers}) do
    Map.to_list(additional_headers) ++ headers
  end

  defp prepare_parts(headers, %{
         attachments: [],
         html_body: html_body,
         text_body: text_body
       }, config) do
    case {text_body, html_body} do
      {text_body, nil} ->
        headers = [{"Content-Type", "text/plain; charset=\"utf-8\""} | headers]
        {"text", "plain", headers, text_body}

      {nil, html_body} ->
        headers = [{"Content-Type", "text/html; charset=\"utf-8\""} | headers]
        {"text", "html", headers, html_body}

      {text_body, html_body} ->
        parts = [
          prepare_part(:plain, text_body, config),
          prepare_part(:html, html_body, config)
        ]
        {"multipart", "alternative", headers, parts}
    end
  end

  defp prepare_parts(headers, %{
         attachments: attachments,
         html_body: html_body,
         text_body: text_body
       }, config) do
    content_part =
      case {prepare_part(:plain, text_body, config), prepare_part(:html, html_body, config)} do
        {text_part, nil} ->
          text_part

        {nil, html_part} ->
          html_part

        {text_part, html_part} ->
          {"multipart", "alternative", [], [], [text_part, html_part]}
      end

    attachment_parts = Enum.map(attachments, &prepare_attachment(&1))

    {"multipart", "mixed", headers, [content_part | attachment_parts]}
  end

  defp prepare_part(_subtype, nil, _config), do: nil

  defp prepare_part(subtype, content, config) do
    subtype_string = to_string(subtype)
    transfer_encoding =
      Keyword.get(config, :transfer_encoding, "quoted-printable")

    {"text", subtype_string,
     [
       {"Content-Type", "text/#{subtype_string}; charset=\"utf-8\""},
       {"Content-Transfer-Encoding", transfer_encoding}
     ],
     [
       {"content-type-params", [{"charset", "utf-8"}]},
       {"disposition", "inline"},
       {"disposition-params", []}
     ], content}
  end

  defp prepare_attachment(
         %{
           filename: filename,
           content_type: content_type,
           type: attachment_type,
           headers: custom_headers
         } = attachment
       ) do
    [type, format] = String.split(content_type, "/")
    content = Swoosh.Attachment.get_content(attachment)

    case attachment_type do
      :attachment ->
        {
          type,
          format,
          [
            {"Content-Transfer-Encoding", "base64"}
            | custom_headers
          ],
          [
            {"disposition", "attachment"},
            {"disposition-params", [{"filename", filename}]}
          ],
          content
        }

      :inline ->
        {
          type,
          format,
          [
            {"Content-Transfer-Encoding", "base64"},
            {"Content-Id", "<#{filename}>"}
            | custom_headers
          ],
          [
            {"content-type-params", []},
            {"disposition", "inline"},
            {"disposition-params", []}
          ],
          content
        }
    end
  end
end
