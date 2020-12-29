defmodule Swoosh.Adapters.Sendinblue do
  @moduledoc ~S"""
  An adapter that sends email using the Sendinblue API (Transactional emails only).

  For reference: [Sendinblue API docs](https://developers.sendinblue.com/reference#transactional-emails)

  ## Example

      # config/config.exs
      config :sample, Sample.Mailer,
        adapter: Swoosh.Adapters.Sendinblue,
        api_key: "my-api-key"

      # lib/sample/mailer.ex
      defmodule Sample.Mailer do
        use Swoosh.Mailer, otp_app: :sample
      end

  ## Provider Options

  - `template_id`
  - `params` (map)
  - `tags` (list)
  """

  use Swoosh.Adapter, required_config: [:api_key]

  alias Swoosh.Email

  @base_url "https://api.sendinblue.com/v3"
  @api_endpoint "/smtp/email"

  @impl true
  def deliver(%Email{} = email, config \\ []) do
    headers = [
      {"Accept", "application/json"},
      {"Content-Type", "application/json"},
      {"User-Agent", "swoosh/#{Swoosh.version()}"},
      {"Api-Key", config[:api_key]}
    ]

    body = email |> prepare_payload() |> Swoosh.json_library().encode!
    url = [@base_url, @api_endpoint]

    case Swoosh.ApiClient.post(url, headers, body, email) do
      {:ok, code, _headers, body} when code >= 200 and code <= 399 ->
        {:ok, body}

      {:ok, code, _headers, body} when code >= 400 ->
        case Swoosh.json_library().decode(body) do
          {:ok, error} -> {:error, {code, error}}
          {:error, _} -> {:error, {code, body}}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp prepare_payload(email) do
    %{}
    |> prepare_from(email)
    |> prepare_to(email)
    |> prepare_cc(email)
    |> prepare_bcc(email)
    |> prepare_text_content(email)
    |> prepare_html_content(email)
    |> prepare_template_id(email)
    |> prepare_params(email)
    |> prepare_tags(email)
    |> prepare_attachments(email)
  end

  defp prepare_from(body, %{from: {name, email}}),
    do: Map.put(body, "sender", %{name: name, email: email})

  defp prepare_from(body, _), do: body

  defp prepare_to(body, %{to: to}) do
    Map.put(body, "to", Enum.map(to, &prepare_recipient/1))
  end

  defp prepare_cc(body, %{cc: cc}) do
    Map.put(body, "cc", Enum.map(cc, &prepare_recipient/1))
  end

  defp prepare_bcc(body, %{bcc: bcc}) do
    Map.put(body, "bcc", Enum.map(bcc, &prepare_recipient/1))
  end

  defp prepare_text_content(body, %{text_body: nil}), do: body

  defp prepare_text_content(body, %{text_body: text_content}) do
    Map.put(body, "textContent", text_content)
  end

  defp prepare_html_content(body, %{html_body: nil}), do: body

  defp prepare_html_content(body, %{html_body: html_content}) do
    Map.put(body, "htmlContent", html_content)
  end

  defp prepare_template_id(body, %{provider_options: %{template_id: template_id}}) do
    Map.put(body, "templateId", template_id)
  end

  defp prepare_template_id(body, _), do: body

  defp prepare_params(body, %{provider_options: %{params: params}}) when is_map(params) do
    Map.put(body, "params", params)
  end

  defp prepare_params(body, _), do: body

  defp prepare_tags(body, %{provider_options: %{tags: tags}}) when is_list(tags) do
    Map.put(body, "tags", tags)
  end

  defp prepare_tags(body, _), do: body

  defp prepare_attachments(body, %{attachments: []}), do: body

  defp prepare_attachments(body, %{attachments: attachments}) do
    Map.put(
      body,
      "attachment",
      Enum.map(
        attachments,
        &%{
          name: &1.filename,
          content: Swoosh.Attachment.get_content(&1, :base64)
        }
      )
    )
  end

  defp prepare_recipient({name, email}) when name in [nil, ""],
    do: %{email: email}

  defp prepare_recipient({name, email}),
    do: %{name: name, email: email}
end
