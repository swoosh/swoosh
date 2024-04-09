defmodule Swoosh.Adapters.Sendinblue do
  @moduledoc ~S"""
  **Deprecated - use Brevo now**

  > Moving from Sendinblue to Brevo
  > https://www.brevo.com/blog/becoming-brevo/

  An adapter that sends email using the Sendinblue API (Transactional emails only).
  For reference: [Sendinblue API docs](https://developers.sendinblue.com/reference/sendtransacemail)
  **This adapter requires an API Client.** Swoosh comes with Hackney, Finch and Req out of the box.
  See the [installation section](https://hexdocs.pm/swoosh/Swoosh.html#module-installation)
  for details.

  ## Example

      # config/config.exs
      config :sample, Sample.Mailer,
        adapter: Swoosh.Adapters.Sendinblue,
        api_key: "my-api-key"
      # lib/sample/mailer.ex
      defmodule Sample.Mailer do
        use Swoosh.Mailer, otp_app: :sample
      end

  ## Using with provider options

      import Swoosh.Email
      new()
      |> from("nora@example.com")
      |> to("shushu@example.com")
      |> subject("Hello, Wally!")
      |> text_body("Hello")
      |> put_provider_option(:id, 42)
      |> put_provider_option(:template_id, 42)
      |> put_provider_option(:params, %{param1: "a", param2: 123})
      |> put_provider_option(:tags, ["tag_1", "tag_2"])
      |> put_provider_option(:schedule_at, ~U[2022-11-15 11:00:00Z])

  ## Provider Options

    * `sender_id` (integer) - `sender`, the sender `id` where this library will
      add email obtained from the `from/1`
    * `template_id` (integer) - `templateId`, the Id of the `active`
      transactional email template
    * `params` (map) - `params`, a map of key/value attributes to customize the
      template
    * `tags` (list[string]) - `tags`, a list of tags for each email for easy
      filtering
    * `schedule_at` (UTC DateTime) - `schedule_at`, a UTC date-time on which the email has to schedule
  """

  use Swoosh.Adapter, required_config: [:api_key]

  alias Swoosh.Email

  @base_url "https://api.sendinblue.com/v3"

  defp base_url(config), do: config[:base_url] || @base_url

  @deprecated "use Swoosh.Adapters.Brevo.deliver/2 instead"
  def deliver(%Email{} = email, config \\ []) do
    Swoosh.Adapters.Brevo.deliver(email, Keyword.merge([base_url: base_url(config)], config))
  end
end
