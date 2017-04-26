defmodule Swoosh.Adapters.Sendgrid do
  @moduledoc ~S"""
  An adapter that sends email using the Sendgrid API.

  For reference: [Sendgrid API docs](https://sendgrid.com/docs/API_Reference/Web_API_v3/Mail/index.html)

  ## Example

      # config/config.exs
      config :sample, Sample.Mailer,
        adapter: Swoosh.Adapters.Sendgrid,
        api_key: "my-api-key"

      # lib/sample/mailer.ex
      defmodule Sample.Mailer do
        use Swoosh.Mailer, otp_app: :sample
      end
  """

  use Swoosh.Adapter, required_config: [:api_key]

  alias Swoosh.Email

  @base_url "https://api.sendgrid.com/v3"
  @api_endpoint "/mail/send"

  def deliver(%Email{} = email, config \\ []) do
    headers = [{"Content-Type", "application/json"},
               {"User-Agent", "swoosh/#{Swoosh.version}"},
               {"Authorization", "Bearer #{config[:api_key]}"}]
    body = email |> prepare_body() |> Poison.encode!
    url = [base_url(config), @api_endpoint]
    case :hackney.post(url, headers, body, [:with_body]) do
      {:ok, code, _headers, _body} when code >= 200 and code <= 399 ->
        {:ok, %{}}
      {:ok, code, _headers, body} when code > 399 ->
        {:error, {code, body}}
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp base_url(config), do: config[:base_url] || @base_url

  defp prepare_body(email) do
    %{}
    |> prepare_from(email)
    |> prepare_personalizations(email)
    |> prepare_subject(email)
    |> prepare_content(email)
    |> prepare_attachments(email)
    |> prepare_reply_to(email)
    |> prepare_template_id(email)
    |> prepare_categories(email)
  end

  defp email_item({"", email}), do: %{email: email}
  defp email_item({name, email}), do: %{email: email, name: name}
  defp email_item(email), do: %{email: email}

  defp prepare_from(body, %{from: from}), do: Map.put(body, :from, from |> email_item)

  defp prepare_personalizations(body, email) do
    personalizations = %{}
      |> prepare_to(email)
      |> prepare_cc(email)
      |> prepare_bcc(email)
      |> prepare_custom_vars(email)
      |> prepare_substitutions(email)

    Map.put(body, :personalizations, [personalizations])
  end
  defp prepare_to(personalizations, %{to: to}), do: Map.put(personalizations, :to, to |> Enum.map(&email_item(&1)))

  defp prepare_cc(personalizations, %{cc: []}), do: personalizations
  defp prepare_cc(personalizations, %{cc: cc}), do: Map.put(personalizations, :cc, cc |> Enum.map(&email_item(&1)))

  defp prepare_bcc(personalizations, %{bcc: []}), do: personalizations
  defp prepare_bcc(personalizations, %{bcc: bcc}), do: Map.put(personalizations, :bcc, bcc |> Enum.map(&email_item(&1)))

  # example custom_vars
  #
  # %{"my_var" => %{"my_message_id": 123},
  #   "my_other_var" => %{"my_other_id": 1, "stuff": 2}}
  defp prepare_custom_vars(personalizations, %{provider_options: %{custom_args: my_vars}}) do
    Map.put(personalizations, :custom_args, my_vars)
  end
  defp prepare_custom_vars(personalizations, _email), do: personalizations

  defp prepare_substitutions(personalizations, %{provider_options: %{substitutions: substitutions}}) do
    Map.put(personalizations, :substitutions, substitutions)
  end
  defp prepare_substitutions(personalizations, _email), do: personalizations

  defp prepare_subject(body, %{subject: subject}), do: Map.put(body, :subject, subject)

  defp prepare_content(body, %{html_body: html, text_body: text}) do
    content = cond do
      html && text -> [%{type: "text/plain", value: text}, %{type: "text/html", value: html}]
      html -> [%{type: "text/html", value: html}]
      text -> [%{type: "text/plain", value: text}]
    end
    Map.put(body, :content, content)
  end
  defp prepare_content(body, %{html_body: html}), do: Map.put(body, :content, [%{type: "text/html", value: html}])
  defp prepare_content(body, %{text_body: text}), do: Map.put(body, :content, [%{type: "text/plain", type: text}])

  defp prepare_attachments(body, %{attachments: []}), do: body
  defp prepare_attachments(body, %{attachments: attachments}) do
    attachments = Enum.map(attachments, fn %{content_type: type, path: path, filename: filename} ->
      content = path |> File.read! |> Base.encode64
      %{type: type, filename: filename, content: content}
    end)

    Map.put(body, :attachments, attachments)
  end

  defp prepare_reply_to(body, %{reply_to: nil}), do: body
  defp prepare_reply_to(body, %{reply_to: reply_to}), do: Map.put(body, :reply_to, reply_to |> email_item)

  defp prepare_template_id(body, %{provider_options: %{template_id: template_id}}) do
    Map.put(body, :template_id, template_id)
  end
  defp prepare_template_id(body, _email), do: body

  defp prepare_categories(body, %{provider_options: %{categories: categories}}) do
    Map.put(body, :categories, categories)
  end
  defp prepare_categories(body, _email), do: body
end
