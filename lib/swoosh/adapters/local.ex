defmodule Swoosh.Adapters.Local do
  @moduledoc ~S"""
  An adapter that stores the email locally, using the specified storage driver.

  This is especially useful in development to avoid sending real emails. You can
  read the emails you have sent using functions in the
  [Swoosh.Adapters.Local.Storage.Memory](Swoosh.Adapters.Local.Storage.Memory.html)
  or the [Plug.Swoosh.MailboxPreview](Plug.Swoosh.MailboxPreview.html) plug.

  ## Example

      # config/config.exs
      config :sample, Sample.Mailer,
        adapter: Swoosh.Adapters.Local

      # lib/sample/mailer.ex
      defmodule Sample.Mailer do
        use Swoosh.Mailer, otp_app: :sample
      end
  """

  use Swoosh.Adapter

  @impl true
  def deliver(%Swoosh.Email{} = email, config) do
    driver = storage_driver(config)
    %Swoosh.Email{headers: %{"Message-ID" => id}} = driver.push(email)

    {:ok, %{id: id}}
  end

  @impl true
  def deliver_many(emails, config) when is_list(emails) do
    driver = storage_driver(config)

    sent_email_ids =
      Enum.map(emails, fn email ->
        %Swoosh.Email{headers: %{"Message-ID" => id}} = driver.push(email)
        %{id: id}
      end)

    {:ok, sent_email_ids}
  end

  defp storage_driver(config) do
    config[:storage_driver] || Swoosh.Adapters.Local.Storage.Memory
  end
end
