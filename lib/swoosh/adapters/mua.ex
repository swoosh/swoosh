defmodule Swoosh.Adapters.Mua do
  @moduledoc """
  An adapter that sends email using the SMTP protocol.

  Underneath this adapter uses [Mua](https://github.com/ruslandoga/mua) and
  [Mail](https://github.com/DockYard/elixir-mail) libraries,
  add them to your mix.exs file.

  ## Example

      # mix.exs
      def deps do
        [
         {:swoosh, "~> 1.3"},
         {:mua, "~> 0.1.0"},
         {:mail, "~> 0.3.0"}
        ]
      end

      # config/config.exs
      config :sample, Sample.Mailer,
        adapter: Swoosh.Adapters.Mua,
        relay: "smtp.matrix.com",
        port: 1025,
        auth: [
          username: "neo",
          password: "one"
        ]

      # lib/sample/mailer.ex
      defmodule Sample.Mailer do
        use Swoosh.Mailer, otp_app: :sample
      end

  ## Note

  For supported configuration options, please see [`Mua.option()`](https://hexdocs.pm/mua/Mua.html#t:option/0)
  """

  @behaviour Swoosh.Adapter

  defmodule MultihostError do
    @moduledoc """
    Raised when no relay is used and recipients contain addresses across multiple hosts.

    For example:

        email =
          Swoosh.Email.new(
            to: {"Mua", "mua@github.com"},
            cc: [{"Swoosh", "mua@swoosh.github.com"}]
          )

        Swoosh.Adapters.Mua.deliver(email, _no_relay_config = %{})

    Fields:

      - `:hosts` - the hosts for the recipients, `["github.com", "swoosh.github.com"]` in the example above

    """

    defexception [:hosts]

    def message(%__MODULE__{hosts: hosts}) do
      "expected all recipients to be on the same host, got: " <> Enum.join(hosts, ", ")
    end
  end

  def deliver(email, config) do
    recipients = recipients(email)

    recipients_by_host =
      if relay = Keyword.get(config, :relay) do
        [{relay, recipients}]
      else
        recipients
        |> Enum.group_by(&recipient_host/1)
        |> Map.to_list()
      end

    case recipients_by_host do
      [{host, recipients}] ->
        sender = address(email.from)
        message = render(email)

        with {:ok, _receipt} <- Mua.easy_send(host, sender, recipients, message, config) do
          {:ok, email}
        end

      [_ | _] = multihost ->
        {:error, MultihostError.exception(hosts: :proplists.get_keys(multihost))}
    end
  end

  def validate_config(_config), do: :ok

  def validate_dependency, do: :ok

  defp address({_, address}) when is_binary(address), do: address
  defp address(address) when is_binary(address), do: address

  defp recipient_host(address) do
    [_username, host] = String.split(address, "@")
    host
  end

  defp recipients(%Swoosh.Email{to: to, cc: cc, bcc: bcc}) do
    (List.wrap(to) ++ List.wrap(cc) ++ List.wrap(bcc))
    |> Enum.map(&address/1)
    |> Enum.uniq()
  end

  defp render(email) do
    Mail.build_multipart()
    |> maybe(&Mail.put_from/2, email.from)
    |> maybe(&Mail.put_to/2, email.to)
    |> maybe(&Mail.put_cc/2, email.cc)
    |> maybe(&Mail.put_bcc/2, email.bcc)
    |> maybe(&Mail.put_subject/2, email.subject)
    |> maybe(&Mail.put_text/2, email.text_body)
    |> maybe(&Mail.put_html/2, email.html_body)
    |> maybe(&put_headers/2, email.headers)
    |> maybe(&put_attachments/2, email.attachments)
    |> Mail.render()
  end

  defp maybe(mail, _fun, empty) when empty in [nil, [], %{}], do: mail
  defp maybe(mail, fun, value), do: fun.(mail, value)

  defp put_attachments(mail, attachments) do
    Enum.reduce(attachments, mail, fn attachment, mail ->
      %Swoosh.Attachment{filename: filename, content_type: content_type} = attachment
      data = Swoosh.Attachment.get_content(attachment)
      headers = [content_type: content_type]
      Mail.put_attachment(mail, {filename, data}, headers: headers)
    end)
  end

  defp put_headers(mail, headers) do
    Enum.reduce(headers, mail, fn {key, value}, mail ->
      Mail.Message.put_header(mail, key, value)
    end)
  end
end
