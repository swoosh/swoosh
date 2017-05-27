defmodule Swoosh.Adapters.Null do
  @moduledoc ~S"""
  An adapter that does nothing at all.

  Useful for e.g. staging servers where you do not want emails to be sent,
  but still want a valid return from `deliver`

  ## Example

      # config/config.exs
      config :sample, Sample.Mailer,
        adapter: Swoosh.Adapters.Null

      # lib/sample/mailer.ex
      defmodule Sample.Mailer do
        use Swoosh.Mailer, otp_app: :sample
      end
  """

  @behaviour Swoosh.Adapter

  def deliver(%Swoosh.Email{} = email, _config) do
    {:ok, :null}
  end
end
