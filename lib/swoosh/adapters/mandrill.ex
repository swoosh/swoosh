defmodule Swoosh.Adapters.Mandrill do
  @moduledoc ~S"""
  An adapter that sends email using the Mandrill API.

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
  """

  use Swoosh.Adapter, required_config: [:api_key]

  alias Swoosh.Email

  @base_url     "https://mandrillapp.com/api/1.0"
  @api_endpoint "/messages/send.json"
  @headers      [{"Content-Type", "application/json"}]

  def deliver(%Email{} = email, config \\ []) do
    body = email |> prepare_body(config) |> Poison.encode!
    url = [base_url(config), @api_endpoint]

    case :hackney.post(url, @headers, body, [:with_body]) do
      {:ok, 200, _headers, body} ->
        interpret_response(body)
      {:ok, code, _headers, body} when code > 399 ->
        {:error, {code, Poison.decode!(body)}}
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp interpret_response(body) when is_binary(body), do: body |> Poison.decode! |> hd |> interpret_response
  defp interpret_response(%{"status" => "sent"} = body), do: {:ok, %{id: body["_id"]}}
  defp interpret_response(%{"status" => "queued"} = body), do: {:ok, %{id: body["_id"]}}
  defp interpret_response(%{"status" => "rejected"} = body), do: {:error, body}
  defp interpret_response(body), do: {:error, Poison.decode!(body)}

  defp base_url(config), do: config[:base_url] || @base_url

  defp prepare_body(email, config) do
    %{message: prepare_message(email)}
    |> set_async(email)
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
    Map.put(body, "attachments", Enum.map(attachments, &%{
      "name" => &1.filename,
      "type" => &1.content_type,
      "content" => &1.path |> File.read! |> Base.encode64
    }))
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
end
