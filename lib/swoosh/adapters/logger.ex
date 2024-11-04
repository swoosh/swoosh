defmodule Swoosh.Adapters.Logger do
  @moduledoc ~S"""
  An adapter that only logs email using Logger.

  It can be useful in environments where you do not necessarily want to send real
  emails (eg. staging environments) or in development.

  By default it only prints the recipient of the email but you can print the full
  email by using `log_full_email: true` in the adapter configuration.

  ## Example

      # config/config.exs
      config :sample, Sample.Mailer,
        adapter: Swoosh.Adapters.Logger,
        level: :debug

      # lib/sample/mailer.ex
      defmodule Sample.Mailer do
        use Swoosh.Mailer, otp_app: :sample
      end
  """

  use Swoosh.Adapter

  require Logger
  import Swoosh.Email.Render

  def deliver(%Swoosh.Email{} = email, config) do
    rendered_email = render(config[:log_full_email] || false, email)
    Logger.log(config[:level] || :info, rendered_email)
    {:ok, %{}}
  end

  defp render(false, email) do
    "New email delivered to #{render_recipient(email.to)}"
  end

  defp render(true, email) do
    recipients = render_recipients(email)
    subject = render_subject(email)
    headers = render_headers(email)
    bodies = render_bodies(email)

    message =
      [recipients, subject, headers, bodies]
      |> Enum.filter(fn text -> text != "" end)
      |> Enum.join("\n")

    "New email delivered\n#{message}"
  end

  defp render_subject(email), do: "Subject: #{email.subject}"

  defp render_recipients(email) do
    [:from, :reply_to, :to, :cc, :bcc]
    |> Enum.map(fn key -> {to_string(key), Map.get(email, key)} end)
    |> Enum.filter(fn
      {_key, value} when is_list(value) -> !Enum.empty?(value)
      {_key, value} -> value
    end)
    |> Enum.map_join("\n", fn {key, value} ->
      String.capitalize(key) <> ": " <> render_recipient(value)
    end)
  end

  defp render_headers(email) do
    Enum.map_join(
      email.headers,
      "\n",
      fn {key, value} -> "#{key}: #{value}" end
    )
  end

  defp render_bodies(email) do
    """

    Text body:
    #{email.text_body}

    HTML body:
    #{email.html_body}
    """
  end
end
