defmodule Swoosh.Adapters.SMTP.Helpers do
  @moduledoc '''
  Prepares a %Swoosh.Email{} for SMTP use
  '''

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

  defp prepare_headers(%Email{} = email) do
    []
    |> prepare_additional_headers(email)
    |> prepare_mime_version
    |> prepare_reply_to(email)
    |> prepare_subject(email)
    |> prepare_cc(email)
    |> prepare_to(email)
    |> prepare_from(email)
  end

  defp prepare_subject(headers, %Email{subject: subject}), do: [{"Subject", subject} | headers]

  defp prepare_from(headers, %Email{from: from}), do: [{"From", render_recipient(from)} | headers]

  defp prepare_to(headers, %Email{to: to}), do: [{"To", render_recipient(to)} | headers]

  defp prepare_cc(headers, %Email{cc: []}), do: headers
  defp prepare_cc(headers, %Email{cc: cc}), do: [{"Cc", render_recipient(cc)} | headers]

  defp prepare_reply_to(headers, %Email{reply_to: nil}), do: headers
  defp prepare_reply_to(headers, %Email{reply_to: reply_to}), do: [{"Reply-To", render_recipient(reply_to)} | headers]

  defp prepare_mime_version(headers), do: [{"Mime-Version", "1.0"} | headers]

  defp prepare_additional_headers(headers, %Email{headers: additional_headers}) do
    Map.to_list(additional_headers) ++ headers
  end

  defp prepare_parts(headers, %Email{html_body: nil, text_body: text_body}) do
    headers = [{"Content-Type", "text/plain; charset=\"utf-8\""} | headers]
    {"text", "plain", headers, text_body}
  end
  defp prepare_parts(headers, %Email{html_body: html_body, text_body: nil}) do
    headers = [{"Content-Type", "text/html; charset=\"utf-8\""} | headers]
    {"text", "html", headers, html_body}
  end
  defp prepare_parts(headers, %Email{html_body: html_body, text_body: text_body}) do
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
end
