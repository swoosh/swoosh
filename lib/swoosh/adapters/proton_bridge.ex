defmodule Swoosh.Adapters.ProtonBridge do
  @moduledoc ~S"""
  An adapter that sends email using the local Protonmail Bridge.

  This is a very thin wrapper around the SMTP adapter.

  Underneath this adapter uses the
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
        adapter: Swoosh.Adapters.ProtonBridge,
        username: "tonystark",
        password: "ilovepepperpotts",

      # lib/sample/mailer.ex
      defmodule Sample.Mailer do
        use Swoosh.Mailer, otp_app: :sample
      end

  ### SMTP

  You can send emails with Protonmail SMTP service via the following SMTP configs,
  using `Swoosh.Adapters.SMTP` adapter.

      [
        relay: "smtp.protonmail.ch",
        ssl: false,
        tls: :always,
        auth: :always,
        port: 587,
        retries: 1,
        no_mx_lookups: false
      ]

  This bridge adapter provides a special set of configs that utilize the local Protonmail Bridge.
  """

  use Swoosh.Adapter, required_config: [], required_deps: [gen_smtp: :gen_smtp_client]

  alias Swoosh.Email
  alias Swoosh.Adapters.SMTP

  def deliver(%Email{} = email, user_config) do
    config = Keyword.merge(bridge_config(), user_config)
    SMTP.deliver(email, config)
  end

  defp bridge_config do
    [
      relay: "127.0.0.1",
      ssl: false,
      tls: :never,
      auth: :always,
      port: 1025,
      retries: 2,
      no_mx_lookups: true
    ]
  end
end
