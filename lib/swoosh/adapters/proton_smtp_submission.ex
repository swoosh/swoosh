defmodule Swoosh.Adapters.ProtonSMTPSubmission do
  @moduledoc ~S"""
  Different from ProtonBridge, this adapter uses the SMTP Submission token not requiring the ProtonMail Bridge to be running.

  To set up the SMTP Submission token, go to Settings -> SMTP/IMAP -> Generate token.
  ![Swoosh.Adapters.ProtonSMTPSubmission](https://github.com/swoosh/swoosh/raw/main/images/proton-token-generator.png)

  As ProtonBridge this also uses the
  [gen_smtp](https://github.com/Vagabond/gen_smtp) library, add it to your mix.exs file.

  ## Example

      # mix.exs
      def deps do
        [
          {:swoosh, "~> 1.3"},
          {:gen_smtp, "~> 1.1"}
        ]
      end

      # config/config.exs
      config :sample, Sample.Mailer,
        adapter: Swoosh.Adapters.ProtonSMTPSubmission,
        username: "[assigned-email-to-token]",
        password: "[generated-on-protonmail.com]",

      # lib/sample/mailer.ex
      defmodule Sample.Mailer do
        use Swoosh.Mailer, otp_app: :sample
      end
  """

  use Swoosh.Adapter, required_config: [], required_deps: [gen_smtp: :gen_smtp_client]

  alias Swoosh.Email
  alias Swoosh.Adapters.SMTP

  @impl true
  def deliver(%Email{} = email, user_config) do
    config = Keyword.merge(bridge_config(), user_config)
    SMTP.deliver(email, config)
  end

  defp bridge_config do
    [
      relay: "smtp.protonmail.ch",
      ssl: false,
      tls: :always,
      auth: :always,
      port: 587,
      retries: 1,
      no_mx_lookups: false
    ]
  end
end
