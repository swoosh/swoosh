defmodule Swoosh.Adapters.SparkPost do
  @moduledoc ~S"""
  An adapter that sends email using the SparkPost API.

  For reference: [SparkPost API docs](https://developers.sparkpost.com/api/)

  ## Example

      # config/config.exs
      config :sample, Sample.Mailer,
        adapter: Swoosh.Adapters.SparkPost,
        api_key: "my-api-key",
        endpoint: "https://api.sparkpost.com/api/v1"
        # or "https://YOUR_DOMAIN.sparkpostelite.com/api/v1" for enterprise

      # lib/sample/mailer.ex
      defmodule Sample.Mailer do
        use Swoosh.Mailer, otp_app: :sample
      end
  """

  use Swoosh.Adapter, required_config: [:api_key]

  alias Swoosh.Email

  @endpoint "https://api.sparkpost.com/api/v1"

  def deliver(%Email{} = email, config \\ []) do
    headers = prepare_headers(email, config)
    body = email |> prepare_body |> Poison.encode!
    url = [endpoint(config), "/transmissions"]

    case :hackney.post(url, headers, body, [:with_body]) do
      {:ok, 200, _headers, body} ->
        {:ok, Poison.decode!(body)}
      {:ok, code, _headers, body} when code > 399 ->
        {:error, {code, Poison.decode!(body)}}
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp endpoint(config), do: config[:endpoint] || @endpoint

  defp prepare_headers(_email, config) do
    [{"User-Agent", "swoosh/#{Swoosh.version}"},
     {"Authorization", config[:api_key]},
     {"Content-Type", "application/json"}]
  end

  defp prepare_body(%{
    from: {name, address},
    to: to,
    subject: subject,
    text_body: text,
    html_body: html,
    attachments: attachments
  } = email) do
    %{
      content: %{
        from: %{
          name: name,
          email: address
        },
        subject: subject,
        text: text,
        html: html,
        headers: %{},
        attachments: prepare_attachments(attachments)
      },
      recipients: prepare_recipients(to, to)
    }
    |> prepare_reply_to(email)
    |> prepare_cc(email)
    |> prepare_bcc(email)
  end

  defp prepare_reply_to(body, %{reply_to: nil}), do: body
  defp prepare_reply_to(body, %{reply_to: reply_to}) do
    put_in(body, [:content, :reply_to], format_recipient(reply_to))
  end

  defp prepare_cc(body, %{cc: []}), do: body
  defp prepare_cc(body, %{cc: cc, to: to}) do
    body
    |> update_in([:recipients], fn list ->
      list ++ prepare_recipients(cc, to)
    end)
    |> put_in([:content, :headers, "CC"], format_recipients(cc))
  end

  defp prepare_bcc(body, %{bcc: []}), do: body
  defp prepare_bcc(body, %{bcc: bcc, to: to}) do
    update_in(body.recipients, fn list ->
      list ++ prepare_recipients(bcc, to)
    end)
  end

  defp prepare_recipients(recipients, to) do
    Enum.map(recipients, fn {name, address} ->
      %{
        address: %{
          name: name,
          email: address,
          header_to: raw_email_addresses(to)
        }
      }
    end)
  end

  defp prepare_attachments(attachments) do
    Enum.map(attachments, fn %{content_type: type, path: path, filename: name} ->
      %{type: type, name: name, data: path |> File.read! |> Base.encode64}
    end)
  end

  defp raw_email_addresses(mailboxes) do
    mailboxes |> Enum.map(fn {_name, address} -> address end) |> Enum.join(",")
  end

  defp format_recipients(recipients) do
    recipients
    |> Enum.map(&format_recipient/1)
    |> Enum.join(", ")
  end

  defp format_recipient({"", address}) do
    [name, _at_domain] = String.split(address, "@", parts: 2)
    format_recipient({name, address})
  end
  defp format_recipient({name, address}), do: "#{name} <#{address}>"
end
