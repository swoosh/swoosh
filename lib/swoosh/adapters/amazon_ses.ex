defmodule Swoosh.Adapters.AmazonSES do
  @moduledoc ~S"""
  An adapter that sends email using the Amazon Simple Email Service Query API.

  This email adapter makes use of the Amazon SES SendRawEmail action and generates
  a SMTP style message containing the information to be emailed. This allows for
  greater more customizable email message and ensures the capability to add
  attachments. As a result, however, the `gen_smtp` dependency is required in order
  to correctly generate the SMTP message that will be sent.

  Ensure sure you have the dependency added in your mix.exs file.

      # You only need to do this if you are using Elixir < 1.4
      def application do
        [applications: [:swoosh, :gen_smtp]]
      end

      def deps do
        [{:swoosh, "~> 0.10.0"},
         {:gen_smtp, "~> 0.12.0"}]
      end

  See Also:

  [Amazon SES Query Api Docs](http://docs.aws.amazon.com/ses/latest/APIReference/Welcome.html)

  [Amazon SES SendRawEmail Documentation](http://docs.aws.amazon.com/ses/latest/APIReference/API_SendRawEmail.html)

  ## Example

      # config/config.exs
      config :sample, Sample.Mailer,
        adapter: Swoosh.Adapters.AmazonSES,
        region: "region-endpoint",
        access_key: "aws-access-key",
        secret: "aws-secret-key"

      # lib/sample/mailer.ex
      defmodule Sample.Mailer do
        use Swoosh.Mailer, otp_app: :sample
      end
  """

  use Swoosh.Adapter,
    required_config: [:region, :access_key, :secret],
    required_deps: [gen_smtp: :mimemail]

  alias Swoosh.Email
  alias Swoosh.Adapters.XML.Helpers, as: XMLHelper
  alias Swoosh.Adapters.SMTP.Helpers, as: SMTPHelper

  @encoding "AWS4-HMAC-SHA256"
  @host_prefix "email."
  @host_suffix ".amazonaws.com"
  @service_name "ses"
  @action "SendRawEmail"
  @base_headers %{"Content-Type" => "application/x-www-form-urlencoded"}
  @version "2010-12-01"

  def deliver(%Email{} = email, config \\ []) do
    query = email |> prepare_body(config) |> encode_body
    url = base_url(config)
    headers = prepare_headers(@base_headers, query, config)

    case :hackney.post(url, headers, query, [:with_body]) do
      {:ok, 200, _headers, body} ->
        {:ok, parse_response(body)}

      {:ok, code, _headers, body} when code > 399 ->
        {:error, parse_error_response(body)}

      {_, reason} ->
        {:error, reason}
    end
  end

  defp parse_response(body) do
    node = XMLHelper.parse(body)
    message_id = XMLHelper.first_text(node, "//MessageId")
    request_id = XMLHelper.first_text(node, "//RequestId")

    %{id: message_id, request_id: request_id}
  end

  defp parse_error_response(body) do
    node = XMLHelper.parse(body)

    code = XMLHelper.first_text(node, "//Error/Code")
    message = XMLHelper.first_text(node, "//Message")

    %{code: code, message: message}
  end

  defp base_url(config) do
    case config[:host] do
      nil -> "https://" <> @host_prefix <> config[:region] <> @host_suffix
      _ -> config[:host]
    end
  end

  defp prepare_body(email, config) do
    %{}
    |> Map.put("Action", @action)
    |> Map.put("Version", Keyword.get(config, :version, @version))
    |> Map.put("RawMessage.Data", generate_raw_message_data(email, config))
  end

  defp encode_body(body) do
    body |> Enum.sort() |> URI.encode_query()
  end

  defp generate_raw_message_data(email, config) do
    email
    |> SMTPHelper.body(config)
    |> Base.encode64()
    |> URI.encode()
  end

  defp prepare_headers(headers, query, config) do
    current_date_time = DateTime.utc_now()

    headers
    |> prepare_header_host(config)
    |> prepare_header_date(current_date_time)
    |> prepare_header_length(query)
    |> prepare_header_authorization(query, current_date_time, config)
    |> Map.to_list()
  end

  defp prepare_header_authorization(headers, query, current_date_time, config) do
    signed_header_list = generate_signed_header_list(headers)
    headers_string = setup_headers_string(headers)

    signature =
      query
      |> determine_request_hash(headers_string, signed_header_list)
      |> generate_signing_string(config, current_date_time)
      |> generate_signature(current_date_time, config[:region], config[:secret])

    authorization =
      prepare_authorization(config, signed_header_list, current_date_time, signature)

    Map.put(headers, "Authorization", authorization)
  end

  defp setup_headers_string(headers) do
    headers
    |> Enum.sort()
    |> Enum.map_join("\n", fn {k, v} -> "#{String.downcase(k)}:#{v}" end)
  end

  defp generate_signed_header_list(headers) do
    headers
    |> Map.keys()
    |> Enum.map_join(";", &String.downcase/1)
  end

  defp determine_request_hash(query, headers, signed_header_list) do
    hashed_query = :crypto.hash(:sha256, query) |> Base.encode16(case: :lower)

    canonical_request =
      [
        "POST",
        "/",
        "",
        "#{headers}",
        "",
        signed_header_list,
        hashed_query
      ]
      |> Enum.join("\n")

    :crypto.hash(:sha256, canonical_request) |> Base.encode16(case: :lower)
  end

  defp prepare_header_host(headers, config) do
    Map.put(headers, "Host", @host_prefix <> config[:region] <> @host_suffix)
  end

  defp prepare_header_date(headers, date_time) do
    Map.put(headers, "X-Amz-Date", amz_datetime(date_time))
  end

  defp prepare_header_length(headers, query) do
    Map.put(headers, "Content-Length", String.length(query))
  end

  defp prepare_authorization(config, signed_header_list, date_time, signature) do
    date = amz_date(date_time)

    credential =
      "#{config[:access_key]}/#{date}/#{config[:region]}/#{@service_name}/aws4_request"

    "#{@encoding} Credential=#{credential}, SignedHeaders=#{signed_header_list}, Signature=#{
      signature
    }"
  end

  defp generate_signature(string_to_sign, date_time, region, secret) do
    ("AWS4" <> secret)
    |> encrypt_value(amz_date(date_time))
    |> encrypt_value(region)
    |> encrypt_value(@service_name)
    |> encrypt_value("aws4_request")
    |> encrypt_value(string_to_sign)
    |> Base.encode16(case: :lower)
  end

  defp generate_signing_string(request_hash, config, dt) do
    date = amz_date(dt)
    normalized_date_time = amz_datetime(dt)

    [
      @encoding,
      "#{normalized_date_time}",
      "#{date}/#{config[:region]}/#{@service_name}/aws4_request",
      request_hash
    ]
    |> Enum.join("\n")
  end

  defp encrypt_value(secret, unencrypted_data),
    do: :crypto.hmac(:sha256, secret, unencrypted_data)

  defp amz_date(dt) do
    date_string =
      Enum.map_join(
        [dt.month, dt.day],
        &String.pad_leading(to_string(&1), 2, "0")
      )

    "#{dt.year}#{date_string}"
  end

  defp amz_datetime(dt) do
    time_string =
      Enum.map_join(
        [dt.hour, dt.minute, dt.second],
        &String.pad_leading(to_string(&1), 2, "0")
      )

    "#{amz_date(dt)}T#{time_string}Z"
  end
end
