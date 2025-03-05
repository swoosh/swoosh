defmodule Swoosh.Adapters.PostUp do
  @moduledoc ~S"""
  An adapter that sends email using the PostUp API, specifically triggered mailing. This
  corresponds to transactional emails.

  API reference: [PostUp API docs](https://apidocs.postup.com/docs/send-a-triggered-mailing)

  **This adapter requires an API Client.** Swoosh comes with Hackney, Finch and Req out of the box.
  See the [installation section](https://hexdocs.pm/swoosh/Swoosh.html#module-installation)
  for details.

  ## Example

      # config/config.exs
      config :sample, Sample.Mailer,
        adapter: Swoosh.Adapters.PostUp,
        username: "BMO",
        password: "hellofootball"

      # lib/sample/mailer.ex
      defmodule Sample.Mailer do
        use Swoosh.Mailer, otp_app: :sample
      end

  ## Using with provider options

  Specify custom tags as a string delimited by semicolons:

      import Swoosh.Email

      new()
      |> from({"BMO", "bmo@example.com"})
      |> to([
        {["FirstName=Finn;LastName=Mertins;custom_tag=Something Else"], "finnthehuman@example.com"},
        {["FirstName=Jake"], "jakethedog@example.com"},
      ])
      |> subject("BMO says hi!")
      |> reply_to("Football@example.com")
      |> html_body("<h1>Hello :)</h1>")
      |> text_body("Hi!")
      |> put_provider_option(:send_template_id, 42)

  ## Usage with just template and no other options

  Use an invalid email address to ignore the `from` option, which is required by Swoosh but causes
  email templates to be overwritten as part of the "context" field in the request body.

      import Swoosh.Email

      new()
      |> from("IGNORED")
      |> to([
        {"FirstName=Finn;LastName=Mertins", "finnthehuman@example.com"},
        {"FirstName=Jake", "jakethedog@example.com"},
      ])
      |> put_provider_option(:send_template_id, 42)

  ## Provider Options

  Note that most of these options are nested under the optional "content" field in the JSON request
  body alongside "fromEmail", "fromName", "htmlBody", etc.

    * `send_template_id` (integer): unique number assigned to each send template.
      **Required field.**

    * `unsub_content_id` (integer): ID for replacement unsubscribe content in specified template.

    * `reply_content_id` (integer): Same as above for "reply" content.

    * `header_content_id` (integer): Same as above for header content.

    * `footer_content_id` (integer): Same as above for footer content.

    * `forward_to_friend_content_id` (integer): Same as above for "forward to friend" content.

  """

  use Swoosh.Adapter, required_config: [:username, :password]

  require Logger
  alias Swoosh.Email

  @base_url "https://api.postup.com/api"
  @api_endpoint "/templatemailing"
  @provider_options [
    :send_template_id,
    :unsub_content_id,
    :reply_content_id,
    :header_content_id,
    :footer_content_id,
    :forward_to_friend_content_id
  ]

  defp base_url(config), do: config[:base_url] || @base_url

  @impl Swoosh.Adapter
  def deliver(%Email{} = email, config \\ []) do
    credentials = Base.encode64("#{config[:username]}:#{config[:password]}")

    headers = [
      {"Accept", "application/json"},
      {"Content-Type", "application/json"},
      {"User-Agent", "swoosh/#{Swoosh.version()}"},
      {"authorization", "Basic #{credentials}"}
    ]

    request_body = email |> prepare_payload() |> Swoosh.json_library().encode!
    url = [base_url(config), @api_endpoint]

    case Swoosh.ApiClient.post(url, headers, request_body, email) do
      {:ok, code, _headers, response_body} when code >= 200 and code <= 399 ->
        Swoosh.json_library().decode(response_body)

      {:ok, code, _headers, body} when code >= 400 ->
        case Swoosh.json_library().decode(body) do
          {:ok, error} -> {:error, {code, error}}
          {:error, _} -> {:error, {code, body}}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp prepare_payload(email) do
    %{}
    |> prepare_from(email)
    |> prepare_reply_to(email)
    |> prepare_to(email)
    |> prepare_subject(email)
    |> prepare_text_content(email)
    |> prepare_html_content(email)
    |> prepare_provider_option(email)
  end

  # fromEmail and fromName are not required fields when using a PostUp template.
  # Swoosh requires a from field; specify some invalid email address to omit it from request body
  defp prepare_from(payload, %Email{from: {name, email}}) when is_binary(email) do
    cond do
      (is_nil(name) or name == "") and not String.match?(email, ~r/^.+@.+\..+$/) ->
        payload

      true ->
        payload
        |> prepare_content("fromEmail", email)
        |> prepare_content("fromName", name)
    end
  end

  defp prepare_reply_to(payload, %Email{reply_to: nil}),
    do: payload

  defp prepare_reply_to(payload, %Email{reply_to: {name, reply_to}}) when name in [nil, ""],
    do: prepare_content(payload, "replyToEmail", reply_to)

  defp prepare_reply_to(payload, %Email{reply_to: {reply_to_name, reply_to_email}}) do
    payload
    |> prepare_content("replyToEmail", reply_to_email)
    |> prepare_content("replyToName", reply_to_name)
  end

  defp prepare_to(payload, %Email{to: to}) do
    recipients = Enum.map(to, &prepare_recipient/1)
    Map.put(payload, "recipients", recipients)
  end

  defp prepare_subject(payload, %Email{subject: ""}), do: payload

  defp prepare_subject(payload, %Email{subject: subject}),
    do: prepare_content(payload, "subject", subject)

  defp prepare_subject(payload, _), do: payload

  defp prepare_text_content(payload, %Email{text_body: nil}), do: payload

  defp prepare_text_content(payload, %Email{text_body: text_body}),
    do: prepare_content(payload, "textBody", text_body)

  defp prepare_html_content(payload, %Email{html_body: nil}), do: payload

  defp prepare_html_content(payload, %Email{html_body: html_content}),
    do: prepare_content(payload, "htmlBody", html_content)

  defp prepare_provider_option(payload, %Email{provider_options: options}) do
    _required = Map.fetch!(options, :send_template_id)

    options
    |> Map.take(@provider_options)
    |> Enum.reduce(payload, fn
      {:send_template_id, send_template_id}, acc ->
        Map.put(acc, "SendTemplateId", send_template_id)

      {key, value}, acc ->
        content_key =
          case key do
            :unsub_content_id -> "unsubContentId"
            :reply_content_id -> "replyContentId"
            :header_content_id -> "headerContentId"
            :footer_content_id -> "footerContentId"
            :forward_to_friend_content_id -> "forwardToFriendContentId"
          end

        prepare_content(acc, content_key, value)
    end)
  end

  defp prepare_recipient({nil, email}),
    do: %{address: email, tags: []}

  defp prepare_recipient({tags, email}) when is_binary(tags),
    do: %{address: email, tags: String.split(tags, ";", trim: true)}

  defp prepare_content(payload, key, value) when is_binary(key) do
    put_in(payload, [Access.key("content", %{}), key], value)
  end
end
