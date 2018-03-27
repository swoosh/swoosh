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
  import Swoosh.Email.Render

  @endpoint "https://api.sparkpost.com/api/v1"

  def deliver(%Email{} = email, config \\ []) do
    headers = prepare_headers(email, config)
    body = email |> prepare_body |> Swoosh.json_library().encode!
    url = [endpoint(config), "/transmissions"]

    case :hackney.post(url, headers, body, [:with_body]) do
      {:ok, 200, _headers, body} ->
        {:ok, Swoosh.json_library().decode!(body)}

      {:ok, code, _headers, body} when code > 399 ->
        {:error, {code, Swoosh.json_library().decode!(body)}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp endpoint(config), do: config[:endpoint] || @endpoint

  defp prepare_headers(_email, config) do
    [
      {"User-Agent", "swoosh/#{Swoosh.version()}"},
      {"Authorization", config[:api_key]},
      {"Content-Type", "application/json"}
    ]
  end

  defp prepare_body(
         %{
           from: {name, address},
           to: to,
           subject: subject,
           text_body: text,
           html_body: html
         } = email
       ) do
    %{
      content: %{
        from: %{
          name: name,
          email: address
        },
        subject: subject,
        text: text,
        html: html,
        headers: %{}
      },
      recipients: prepare_recipients(to, to)
    }
    |> prepare_reply_to(email)
    |> prepare_cc(email)
    |> prepare_bcc(email)
    |> prepare_custom_headers(email)
    |> prepare_attachments(email)
  end

  defp prepare_reply_to(body, %{reply_to: nil}), do: body

  defp prepare_reply_to(body, %{reply_to: reply_to}) do
    put_in(body, [:content, :reply_to], render_recipient(reply_to))
  end

  defp prepare_cc(body, %{cc: []}), do: body

  defp prepare_cc(body, %{cc: cc, to: to}) do
    body
    |> update_in([:recipients], fn list ->
      list ++ prepare_recipients(cc, to)
    end)
    |> put_in([:content, :headers, "CC"], render_recipient(cc))
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

  defp raw_email_addresses(mailboxes) do
    mailboxes |> Enum.map(fn {_name, address} -> address end) |> Enum.join(",")
  end

  defp prepare_attachments(body, %{attachments: []}), do: body

  defp prepare_attachments(body, %{attachments: attachments}) do
    {standalone_attachments, inline_attachments} =
      Enum.split_with(attachments, fn %{type: type} -> type == :attachment end)

    body
    |> inject_attachments(:attachments, standalone_attachments)
    |> inject_attachments(:inline_images, inline_attachments)
  end

  defp inject_attachments(body, _key, []), do: body

  defp inject_attachments(body, key, attachments) do
    Map.put(
      body,
      key,
      Enum.map(attachments, fn %{content_type: type, filename: name} = attachment ->
        %{type: type, name: name, data: Swoosh.Attachment.get_content(attachment, :base64)}
      end)
    )
  end

  defp prepare_custom_headers(body, %{headers: headers}) do
    custom_headers = Map.merge(body.content.headers, headers)
    put_in(body, [:content, :headers], custom_headers)
  end
end
