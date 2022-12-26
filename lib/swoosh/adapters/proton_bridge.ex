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
