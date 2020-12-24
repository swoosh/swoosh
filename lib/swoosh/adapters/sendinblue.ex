defmodule Swoosh.Adapters.Sendinblue do
  @moduledoc ~S"""
  An adapter that sends email using the Sendinblue API (Transactional emails only).

  For reference: [Sendinblue API docs](https://developers.sendinblue.com/docs/send-a-transactional-email)

  ## Example

      # config/config.exs
      config :sample, Sample.Mailer,
        adapter: Swoosh.Adapters.Sendinblue,
        api_key: "my-api-key"

      # lib/sample/mailer.ex
      defmodule Sample.Mailer do
        use Swoosh.Mailer, otp_app: :sample
      end
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
    |> prepare_template_id(email)
    |> prepare_params(email)
    |> prepare_attachments(email)
  end

  defp prepare_from(body, %{from: {name, email}}),
    do: Map.put(body, :sender, %{name: name, email: email})

  defp prepare_from(body, _), do: body

  defp prepare_to(body, %{to: to}) when is_list(to),
    do: Enum.reduce(to, body, &prepare_to(&2, &1))

  defp prepare_to(body, {name, email}) when name in [nil, ""] and not is_map_key(body, :to),
    do: Map.put(body, :to, [%{email: email}])

  defp prepare_to(body, {name, email}) when not is_map_key(body, :to),
    do: Map.put(body, :to, [%{name: name, email: email}])

  defp prepare_to(body, {name, email}) when name in [nil, ""],
    do: Map.update!(body, :to, &[%{email: email} | &1])

  defp prepare_to(body, {name, email}),
    do: Map.update!(body, :to, &[%{name: name, email: email} | &1])

  defp prepare_template_id(body, %{provider_options: %{template_id: template_id}}) do
    Map.put(body, :templateId, template_id)
  end

  defp prepare_template_id(body, _), do: body

  defp prepare_params(body, %{provider_options: %{params: params}}) do
    Map.put(body, :params, params)
  end

  defp prepare_params(body, _), do: body

  defp prepare_attachments(body, %{attachments: []}), do: body

  defp prepare_attachments(body, %{attachments: attachments}) do
    attachments =
      Enum.map(attachments, fn attachment ->
        %{
          name: attachment.filename,
          content: Swoosh.Attachment.get_content(attachment, :base64)
        }
      end)

    Map.put(body, :attachment, attachments)
  end
end
