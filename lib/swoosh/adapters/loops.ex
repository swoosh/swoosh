defmodule Swoosh.Adapters.Loops do
  @moduledoc ~s"""
  An adapter that sends email using the Loops API.

  For reference: [Loops API docs](https://loops.so/docs/api-reference/send-transactional-email)

  **This adapter requires an API Client.** Swoosh comes with Hackney, Finch and Req out of the box.
  See the [installation section](https://hexdocs.pm/swoosh/Swoosh.html#module-installation)
  for details.

  ## Example

      # config/config.exs
      config :sample, Sample.Mailer,
        adapter: Swoosh.Adapters.Loops,
        api_key: "my-api-key"
      # lib/sample/mailer.ex
      defmodule Sample.Mailer do
        use Swoosh.Mailer, otp_app: :sample
      end

  ## Using with provider options

      import Swoosh.Email

      new()
      |> to("katy@example.com")
      |> from("IGNORED") # see note below
      |> put_provider_option(:data_variables, %{
          "name" => "Chris",
          "passwordResetLink" => "https://example.com/reset-password"
        })
      |> put_provider_option(:transactional_id, "clfq6dinn000yl70fgwwyp82l")

  Note that we need to provide a `from` because it's required by Swoosh. This will
  be ignored though, since Loops API doesn't support setting a sender.

  ## Provider Options

  Supported provider options are the following:

  #### Inserted into request payload

    * `:transactional_id` (string) - The ID of the transactional email to send.

    * `:add_to_audience?` (boolean) - If true, a contact will be created in your audience
      using the email value (if a matching contact doesn’t already exist). Disabled by
      default.

    * `:data_variables` (map) - An object containing data as defined by the data variables
      added to the transactional email template. Values can be of type string or number.
  """

  use Swoosh.Adapter, required_config: [:api_key]

  alias Swoosh.Email

  import Swoosh.Email.Render

  @base_url "https://app.loops.so/api/v1"
  @api_endpoint "/transactional"

  @impl Swoosh.Adapter
  def deliver(%Email{} = email, config \\ []) do
    headers = [
      {"Content-Type", "application/json"},
      {"User-Agent", "swoosh/#{Swoosh.version()}"},
      {"Authorization", "Bearer #{config[:api_key]}"}
    ]

    payload = email |> prepare_payload() |> Swoosh.json_library().encode!
    url = [base_url(config), @api_endpoint]

    case Swoosh.ApiClient.post(url, headers, payload, email) do
      {:ok, code, _headers, _body} when code >= 200 and code <= 399 ->
        {:ok, %{}}

      {:ok, code, _headers, body} when code >= 400 ->
        case Swoosh.json_library().decode(body) do
          {:ok, error} -> {:error, {code, error}}
          {:error, _} -> {:error, {code, body}}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp base_url(config), do: config[:base_url] || @base_url

  defp prepare_payload(email) do
    %{}
    |> prepare_to(email)
    |> prepare_provider_options_payload_fields(email)
    |> prepare_attachments(email)
  end

  defp prepare_to(payload, %Email{to: to}),
    do: Map.put(payload, "email", render_recipient(to))

  defp prepare_provider_options_payload_fields(payload, %Email{provider_options: provider_options}) do
    Map.merge(payload, %{
      "transactionalId" => provider_options.transactional_id,
      "addToAudience" => provider_options[:add_to_audience?] || false,
      "dataVariables" => provider_options[:data_variables] || %{}
    })
  end

  defp prepare_attachments(payload, %{attachments: []}), do: payload

  defp prepare_attachments(payload, %{attachments: attachments}) do
    Map.put(
      payload,
      "attachments",
      Enum.map(
        attachments,
        &%{
          "filename" => &1.filename,
          "contentType" => &1.content_type,
          "data" => Swoosh.Attachment.get_content(&1, :base64)
        }
      )
    )
  end
end
