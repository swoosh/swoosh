if Code.ensure_loaded?(:mimemail) do
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
      {type, subtype, headers, parts} = prepare_message(email)
      options = prepare_options(config)
      :mimemail.encode({type, subtype, headers, [], parts}, options)
    end

    @doc false
    def prepare_message(email) do
      email
      |> prepare_headers()
      |> prepare_parts(email)
    end

    @doc false
    def prepare_options(config) do
      case config[:dkim] do
        nil -> []
        dkim -> [dkim: dkim]
      end
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
    defp prepare_reply_to(headers, %{reply_to: reply_to}), do: [{"Reply-To", render_recipient(reply_to)} | headers]

    defp prepare_mime_version(headers), do: [{"Mime-Version", "1.0"} | headers]

    defp prepare_additional_headers(headers, %{headers: additional_headers}) do
      Map.to_list(additional_headers) ++ headers
    end

    defp prepare_parts(headers, %{
      attachments: attachments,
      html_body: html_body,
      text_body: text_body
    }) when length(attachments) > 0 do
      parts = Enum.map(attachments, &prepare_attachment(&1))
      parts = if text_body, do: [prepare_part(:plain, text_body) | parts], else: parts
      parts = if html_body, do: [prepare_part(:html, html_body) | parts], else: parts

      {"multipart", "mixed", headers, parts}
    end
    defp prepare_parts(headers, %{html_body: nil, text_body: text_body}) do
      headers = [{"Content-Type", "text/plain; charset=\"utf-8\""} | headers]
      {"text", "plain", headers, text_body}
    end
    defp prepare_parts(headers, %{html_body: html_body, text_body: nil}) do
      headers = [{"Content-Type", "text/html; charset=\"utf-8\""} | headers]
      {"text", "html", headers, html_body}
    end
    defp prepare_parts(headers, %{html_body: html_body, text_body: text_body}) do
      parts = [prepare_part(:plain, text_body), prepare_part(:html, html_body)]
      {"multipart", "alternative", headers, parts}
    end

    defp prepare_part(subtype, content) do
      subtype_string = to_string(subtype)
      {"text",
       subtype_string,
       [{"Content-Type", "text/#{subtype_string}; charset=\"utf-8\""},
        {"Content-Transfer-Encoding", "quoted-printable"}],
       [{"content-type-params", [{"charset", "utf-8"}]},
        {"disposition", "inline"},
        {"disposition-params",[]}],
       content}
    end

    defp prepare_attachment(%{filename: filename, path: path, content_type: content_type}) do
      [type, format] = String.split(content_type, "/")
      file = File.read!(path)

      {type, format,
       [{"Content-Transfer-Encoding", "base64"}],
       [{"disposition", "attachment"}, {"disposition-params", [{"filename", filename}]}],
       file}
    end
  end
end
