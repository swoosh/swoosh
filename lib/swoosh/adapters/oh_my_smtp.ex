defmodule Swoosh.Adapters.OhMySmtp do
  @moduledoc ~S"""

  **Deprecated - use MailPace now**

  > Moving from OhMySMTP to MailPace
  > https://docs.mailpace.com/guide/moving_from_ohmysmtp

  An adapter that sends email using the OhMySMTP API.

  For reference: [OhMySMTP API docs](https://docs.ohmysmtp.com/reference/overview)

  **This adapter requires an API Client.** Swoosh comes with Hackney, Finch and Req out of the box.
  See the [installation section](https://hexdocs.pm/swoosh/Swoosh.html#module-installation)
  for details.

  ## Example

      # config/config.exs
      config :sample, Sample.Mailer,
        adapter: Swoosh.Adapters.OhMySmtp,
        api_key: "my-api-key"

      # lib/sample/mailer.ex
      defmodule Sample.Mailer do
        use Swoosh.Mailer, otp_app: :sample
      end
  """

  use Swoosh.Adapter, required_config: [:api_key]

  alias Swoosh.Email

  @endpoint "https://app.ohmysmtp.com/api/v1/send"

  defp endpoint(config), do: config[:endpoint] || @endpoint

  @deprecated "use Swoosh.Adapter.MailPace.deliver/2 instead"
  def deliver(%Email{} = email, config \\ []) do
    Swoosh.Adapters.MailPace.deliver(
      email,
      Keyword.merge(
        [
          endpoint: endpoint(config),
          server_token_key: "OhMySMTP-Server-Token"
        ],
        config
      )
    )
  end
end
