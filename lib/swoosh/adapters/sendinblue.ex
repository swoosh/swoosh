defmodule Swoosh.Adapters.Sendinblue do
  @moduledoc !"deprecated - use Brevo now"

  use Swoosh.Adapter, required_config: [:api_key]

  alias Swoosh.Email

  @base_url "https://api.sendinblue.com/v3"

  defp base_url(config), do: config[:base_url] || @base_url

  @impl true
  @deprecated "use Brevo instead"
  def deliver(%Email{} = email, config \\ []) do
    Swoosh.Adapters.Brevo.deliver(email, Keyword.merge([base_url: base_url(config)], config))
  end
end
