defmodule Swoosh.Adapters.SparkPost do
  @moduledoc ~S"""
  An adapter that sends email using the SparkPost API.

  For reference: [SparkPost API docs](https://developers.sparkpost.com/api/)

  **This adapter requires an API Client.** Swoosh comes with Hackney, Finch and Req out of the box.
  See the [installation section](https://hexdocs.pm/swoosh/Swoosh.html#module-installation)
  for details.

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

  ## Using with SparkPost templates

      import Swoosh.Email

      new()
      |> from("tony.stark@example.com")
      |> to("steve.rogers@example.com")
      |> subject("Hello, Avengers!")
      |> put_provider_option(:template_id, "my-first-email")
      |> put_provider_option(:substitution_data, %{
        first_name: "Peter",
        last_name: "Parker"
      })

  ## Setting SparkPost transmission options

  Full options can be found at [SparkPost Transmissions API Docs](https://developers.sparkpost.com/api/transmissions/#header-request-body)

      import Swoosh.Email

      new()
      |> from("tony.stark@example.com")
      |> to("steve.rogers@example.com")
      |> subject("Hello, Avengers!")
      |> put_provider_option(:options, %{
        click_tracking: false,
        open_tracking: false,
        transactional: true,
        inline_css: true
      })

  ## Provider Options

    * `:options` (map) - customization on how the email is sent

    * `:template_id` (string) - id of the template to use

    * `:substitution_data` (map) - data passed to the template language in
      the content, and take precedence over the other data like `:metadata`

  """

  use Swoosh.Adapter, required_config: [:api_key]

  alias Swoosh.Email
  import Swoosh.Email.Render

  @endpoint "https://api.sparkpost.com/api/v1"

  def deliver(%Email{} = email, config \\ []) do
    headers = prepare_headers(email, config)
    body = email |> prepare_body |> Swoosh.json_library().encode!
    url = [endpoint(config), "/transmissions"]

    case Swoosh.ApiClient.post(url, headers, body, email) do
      {:ok, 200, _headers, body} ->
        {:ok, Swoosh.json_library().decode!(body)}

      {:ok, code, _headers, body} when code > 399 ->
        case Swoosh.json_library().decode(body) do
          {:ok, error} -> {:error, {code, error}}
          {:error, _} -> {:error, {code, body}}
        end

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
    |> prepare_template_id(email)
    |> prepare_substitutions(email)
    |> prepare_options(email)
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
    mailboxes |> Enum.map_join(",", fn {_name, address} -> address end)
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
    put_in(
      body.content[key],
      Enum.map(attachments, fn %{content_type: type, filename: name} = attachment ->
        %{type: type, name: name, data: Swoosh.Attachment.get_content(attachment, :base64)}
      end)
    )
  end

  defp prepare_template_id(body, %{provider_options: %{template_id: template_id}}) do
    put_in(body, [:content, :template_id], template_id)
  end

  defp prepare_template_id(body, _email), do: body

  defp prepare_substitutions(body, %{provider_options: %{substitution_data: substitution_data}}) do
    Map.put(body, :substitution_data, substitution_data)
  end

  defp prepare_substitutions(body, _email), do: body

  defp prepare_options(body, %{provider_options: %{options: options}}) do
    Map.put(body, :options, options)
  end

  defp prepare_options(body, _email), do: body

  defp prepare_custom_headers(body, %{headers: headers}) do
    custom_headers = Map.merge(body.content.headers, headers)
    put_in(body, [:content, :headers], custom_headers)
  end
end
