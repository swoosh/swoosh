defmodule Swoosh.Adapters.AmazonSES do
  @moduledoc ~S"""
  An adapter that sends email using the Amazon Simple Email Service (SES) Query API.
  This adapter does not depend on `ExAws`; if you are already using it, you may
  prefer `Swoosh.Adapters.ExAwsAmazonSES`.

  This email adapter makes use of the Amazon SES SendRawEmail action and generates
  a SMTP style message containing the information to be emailed. This allows for
  greater and more customizable email message and ensures the capability to add
  attachments. As a result, however, the `:gen_smtp` dependency is required in order
  to correctly generate the SMTP message that will be sent.

  Ensure you have the dependency added in your mix.exs file:

      def deps do
        [
          {:swoosh, "~> 1.0"},
          {:gen_smtp, "~> 1.0"}
        ]
      end

  **Note**: If Swoosh was compiled prior to `:gen_smtp` being installed, it may be necessary to
  force a recompilation of the library. This can be accomplished using `mix deps.compile swoosh --force`.

  **This adapter requires an API Client.** Swoosh comes with Hackney, Finch and Req out of the box.
  See the [installation section](https://hexdocs.pm/swoosh/Swoosh.html#module-installation)
  for details.

  See also:

  [Amazon SES Query Api Docs](http://docs.aws.amazon.com/ses/latest/APIReference/Welcome.html)

  [Amazon SES SendRawEmail Documentation](http://docs.aws.amazon.com/ses/latest/APIReference/API_SendRawEmail.html)

  ## Configuration options

  ### Required

  Note that these are handled automatically if using `Swoosh.Adapters.ExAwsAmazonSES`.

  * `:region` - the AWS region
  * `:access_key` - the IAM access key
  * `:secret` - the IAM secret

  ### Optional

  The following [request parameters](https://docs.aws.amazon.com/ses/latest/APIReference/API_SendRawEmail.html#API_SendRawEmail_RequestParameters) can be set in the configuration:

  * `:ses_source` - mapped to `Source` parameter in the API request
  * `:ses_source_arn` - mapped to `SourceArn` parameter in the API request
  * `:ses_from_arn` - mapped to `FromArn` parameter in the API request
  * `:ses_return_path_arn` - mapped to `ReturnPathArn` parameter in the API request

  See details on how to use the parameters from [the SES API documentation](https://docs.aws.amazon.com/ses/latest/APIReference/API_SendRawEmail.html#API_SendRawEmail_RequestParameters).

  ## Examples

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

  ## Using with tags and configuration set

      import Swoosh.Email

      new()
      |> from("guybrush.threepwood@pirates.grog")
      |> to("elaine.marley@triisland.gov")
      |> subject("Mighty Pirate Newsletter")
      |> text_body("Hello")
      |> put_provider_option(:tags, [%{name: "name1", value: "test1"}])
      |> put_provider_option(:configuration_set_name, "configuration_set_name1")

  ## Provider Options

    * `:tags` (list[map]) - a list of key/value pairs of a tag
    * `:configuration_set_name` (string) - the name of the configuration set
    * `:security_token` (string) - temporary security token obtained through
      AWS Security Token Service (AWS STS)

  ## IAM role

  In case you use IAM role for authenticating AWS requests, you can fetch
  temporary `:access_key` and `:secret_key` from that role, but you also need to
  include additional `X-Amz-Security-Token` header to that request.

  You can do that by adding `:security_token` to `:provider_options`.

  If you don't have a static `:access_key` and `:secret_key` for your
  application, you can use the `Swoosh.Adapters.ExAwsAmazonSES` adapter to fetch credentials
  on-demand as specified in your application's `:ex_aws` configuration.
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
    headers = prepare_headers(@base_headers, query, config, email.provider_options)

    case Swoosh.ApiClient.post(url, headers, query, email) do
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
    |> prepare_source(config)
    |> prepare_source_arn(config)
    |> prepare_from_arn(config)
    |> prepare_return_path_arn(config)
    |> prepare_configuration_set_name(email)
    |> prepare_tags(email)
  end

  defp encode_body(body) do
    body |> Enum.sort() |> URI.encode_query()
  end

  defp prepare_configuration_set_name(body, %{provider_options: %{configuration_set_name: name}}) do
    Map.put(body, "ConfigurationSetName", name)
  end

  defp prepare_configuration_set_name(body, _email), do: body

  defp prepare_source(body, config) do
    case Keyword.fetch(config, :ses_source) do
      {:ok, source} -> Map.put(body, "Source", source)
      :error -> body
    end
  end

  defp prepare_source_arn(body, config) do
    case Keyword.fetch(config, :ses_source_arn) do
      {:ok, source} -> Map.put(body, "SourceArn", source)
      :error -> body
    end
  end

  defp prepare_from_arn(body, config) do
    case Keyword.fetch(config, :ses_from_arn) do
      {:ok, from} -> Map.put(body, "FromArn", from)
      :error -> body
    end
  end

  defp prepare_return_path_arn(body, config) do
    case Keyword.fetch(config, :ses_return_path_arn) do
      {:ok, return_path} -> Map.put(body, "ReturnPathArn", return_path)
      :error -> body
    end
  end

  defp prepare_tags(body, %{provider_options: %{tags: tags}}) do
    Map.merge(
      body,
      tags
      |> Enum.with_index(1)
      |> Enum.flat_map(fn {%{name: name, value: value}, index} ->
        [{"Tags.member.#{index}.Name", name}, {"Tags.member.#{index}.Value", value}]
      end)
      |> Enum.into(%{})
    )
  end

  defp prepare_tags(body, _email), do: body

  defp generate_raw_message_data(email, config) do
    email
    |> SMTPHelper.body([{:keep_bcc, true} | config])
    |> Base.encode64()
    |> URI.encode()
  end

  defp prepare_headers(headers, query, config, provider_options) do
    current_date_time = DateTime.utc_now()

    headers
    |> prepare_header_host(config)
    |> prepare_header_date(current_date_time)
    |> prepare_header_length(query)
    |> prepare_header_authorization(query, current_date_time, config)
    |> prepare_header_security_token(provider_options)
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
    Map.put(headers, "Content-Length", query |> String.length() |> to_string())
  end

  defp prepare_authorization(config, signed_header_list, date_time, signature) do
    date = amz_date(date_time)

    credential = "#{config[:access_key]}/#{date}/#{config[:region]}/#{@service_name}/aws4_request"

    "#{@encoding} Credential=#{credential}, SignedHeaders=#{signed_header_list}, Signature=#{signature}"
  end

  defp prepare_header_security_token(headers, %{security_token: token}) do
    Map.put(headers, "X-Amz-Security-Token", token)
  end

  defp prepare_header_security_token(headers, _provider_options), do: headers

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
    do: :crypto.mac(:hmac, :sha256, secret, unencrypted_data)

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
