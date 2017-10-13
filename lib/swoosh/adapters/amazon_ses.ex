defmodule Swoosh.Adapters.AmazonSes do
  @moduledoc ~S"""
  An adapter that sends email using the Amazon Simple Email Service Query API.

  For reference: [Amazone SES Query Api Docs](http://docs.aws.amazon.com/ses/latest/APIReference/Welcome.html)

  ## Example

      # config/config.exs
      config :sample, Sample.Mailer,
        adapter: Swoosh.Adapters.AmazonSes,
        region: 'region-endpoint',
        access_key: 'aws-access-key',
        secret: 'aws-secret-key'

      # lib/sample/mailer.ex
      defmodule Sample.Mailer do
        use Swoosh.Mailer, otp_app: :sample
      end
  """

  use Swoosh.Adapter, required_config: [:region, :access_key, :secret]
  alias Swoosh.Email
  alias Swoosh.Adapters.XML.Helpers, as: XmlHelper
  alias Swoosh.Adapters.SMTP.Helpers, as: SMTPHelper

  @encoding     "AWS4-HMAC-SHA256"
  @host_prefix  "email."
  @host_suffix  ".amazonaws.com"
  @service_name "ses"
  @action       "SendRawEmail"
  @base_headers %{"Content-Type" => "application/x-www-form-urlencoded"}
  @version      "2010-12-01"

  def deliver(%Email{} = email, config \\ []) do
    body = email |> prepare_body(config) |> encode_body
    url = base_url(config)
    headers = prepare_headers(@base_headers, body, config)

    case :hackney.post(url, headers, body, [:with_body]) do
      {:ok, 200, _headers, body} -> {:ok, interpret_response(body)}
      {:ok, code, _headers, body} when code > 399 ->
        {:error, interpret_error_response(body)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp interpret_response(body) do
    id =
      body
      |> XmlHelper.parse
      |> XmlHelper.first("//MessageId")
      |> XmlHelper.text

    %{id: id}
  end

  defp interpret_error_response(body) do
    IO.inspect body
    node =
      body
      |> XmlHelper.parse

    code =
      node
      |> XmlHelper.first("//Error/Code")
      |> XmlHelper.text

    message =
      node
      |> XmlHelper.first("//Error/Message")
      |> XmlHelper.text

    %{code: code, message: message}
  end

  defp base_url(config) do
    case config[:host] do
      nil -> "https://" <> @host_prefix <> config[:region] <> @host_suffix
      _ -> config[:host]
    end
  end

  defp version(config) do
    case config[:version] do
      nil -> @version
      _ -> config[:version]
    end
  end

  defp prepare_body(email, config) do
    raw_body =
      SMTPHelper.body(email, config)
      |> Base.encode64
      |> URI.encode_www_form

    %{}
    |> Map.put("Action", @action)
    |> Map.put("Version", version(config))
    |> Map.put("RawMessage.Data", raw_body)
    # |> prepare_source(from)
    # |> prepare_recipients(to)
    # |> prepare_recipients(cc, "CcAddresses")
    # |> prepare_recipients(bcc, "BccAddresses")
    # |> prepare_reply_to(email)
    # |> prepare_subject(email)
    # |> prepare_content(email)
  end

  defp prepare_content(body, email) do
    body
    |> prepare_html(email)
    |> prepare_text(email)
  end

  defp prepare_content(body, _), do: body

  defp prepare_source(body, {"", from_email}), do: Map.put(body, "Source", from_email)
  defp prepare_source(body, {from_name, from_email}) do
    Map.put(body, "Source", "\"#{from_name}\" <#{from_email}>")
  end

  defp prepare_recipients(body, emails, type \\ "ToAddresses", count \\ 1)
  defp prepare_recipients(body, [{name, address} | tail], type, count) when name == "" or name == nil do
    Map.put(body, "Destination.#{type}.member.#{count}", address)
    |> prepare_recipients(tail, type, count + 1)
  end

  defp prepare_recipients(body, [{name, address} | tail], type, count) do
    Map.put(body, "Destination.#{type}.member.#{count}", "\"#{name}\" <#{address}>")
    |> prepare_recipients(tail, type, count + 1)
  end

  defp prepare_reply_to(body, %{reply_to: nil}), do: body
  defp prepare_reply_to(body, %{reply_to: reply_to}), do: prepare_reply_to(body, reply_to)
  defp prepare_reply_to(body, [{_name, address} | tail], count \\ 0) do
    body
    |> Map.put("ReplyToAddresses.member.#{count}", address)
    |> prepare_reply_to(tail, count)
  end
  defp prepare_reply_to(body, [], _), do: body

  defp prepare_recipients(body, [], _, _), do: body

  defp encode_body(body) do
    Map.keys(body)
    |> Enum.sort
    |> Enum.map(fn(key) -> "#{key}=#{body[key]}" end)
    |> Enum.join("&")
    |> URI.encode
  end

  defp prepare_headers(headers, body, config) do
    signed_header_list = "content-type;host;x-amz-date"
    current_date_time = DateTime.utc_now()

    headers =
      headers
      |> prepare_header_host(config)
      |> prepare_header_date(config, current_date_time)

    headers_string = setup_headers_string(headers)
    signature =
      determine_request_hash(body, headers_string, signed_header_list)
      |> generate_signing_string(config, current_date_time)
      |> generate_signature(current_date_time, signed_header_list, config[:region], config[:access_key], config[:secret])

    prepare_authorization(headers, config, signed_header_list, current_date_time, signature)
    |> Enum.map(fn {k, v} -> {k, v} end)
  end

  defp setup_headers_string(headers) do
    Map.keys(headers)
    |> Enum.sort
    |> Enum.map(fn(key) -> "#{String.downcase(key)}:#{headers[key]}" end)
    |> Enum.join("\n")
  end

  defp determine_request_hash(query, headers, signed_header_list) do
    canonical_request =
      [
        "POST",
        "/",
        "",
        "#{headers}",
        "",
        signed_header_list,
        :crypto.hash(:sha256, query) |> Base.encode16 |> String.downcase
      ]
      |> Enum.join("\n")

    :crypto.hash(:sha256, canonical_request) |> Base.encode16 |> String.downcase
  end

  defp prepare_header_host(headers, config) do
    Map.put(headers, "Host", @host_prefix <> config[:region] <> @host_suffix)
  end

  defp prepare_authorization(headers, config, signed_header_list, date_time, signature) do
    date = extract_date_string(date_time)
    credential = "#{config[:access_key]}/#{date}/#{config[:region]}/#{@service_name}/aws4_request"
    authorization = "#{@encoding} Credential=#{credential}, SignedHeaders=#{signed_header_list}, Signature=#{signature}"
    Map.put(headers, "Authorization", authorization)
  end

  defp generate_signature(string_to_sign, date_time, signed_header_list, region, access_key, secret) do
    encrypt_value("AWS4" <> secret, extract_date_string(date_time))
    |> encrypt_value(region)
    |> encrypt_value(@service_name)
    |> encrypt_value("aws4_request")
    |> encrypt_value(string_to_sign)
    |> Base.encode16
    |> String.downcase
  end

  defp encrypt_value(secret, unencrypted_data), do: :crypto.hmac(:sha256, secret, unencrypted_data)

  defp extract_date_string(dt), do: "#{dt.year}#{dt.month}#{dt.day}"

  defp generate_signing_string(request_hash, config, dt) do
    date = extract_date_string(dt)
    normalized_date_time = normalize_iso8601(dt)

    [
      @encoding,
      "#{normalized_date_time}",
      "#{date}/#{config[:region]}/#{@service_name}/aws4_request",
      request_hash
    ]
    |> Enum.join("\n")
  end

  defp normalize_iso8601(dt) do
    date = extract_date_string(dt)
    {_, time} = Time.new(dt.hour, dt.minute, dt.second)
    time_string = Time.to_string(time) |> String.replace(":", "")
    "#{date}T#{time_string}Z"
  end

  defp prepare_header_date(headers, config, date_time) do
    Map.put(headers, "X-Amz-Date", normalize_iso8601(date_time))
  end

  defp prepare_subject(body, %{subject: subject}), do: Map.put(body, "Message.Subject.Data", subject)

  defp prepare_text(body, %{text_body: nil}), do: body
  defp prepare_text(body, %{text_body: text_body}), do: Map.put(body, "Message.Body.Text.Data", text_body)

  defp prepare_html(body, %{html_body: nil}), do: body
  defp prepare_html(body, %{html_body: html_body}), do: Map.put(body, "Message.Body.Html.Data", html_body)

  defp prepare_custom_headers(body, %{headers: headers}) when map_size(headers) == 0, do: body
  defp prepare_custom_headers(body, %{headers: headers}) do
    custom_headers =  Map.merge(body[:headers] || %{}, headers)
    Map.put(body, :headers, custom_headers)
  end
end
