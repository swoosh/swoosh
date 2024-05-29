defmodule Swoosh.Adapters.ExAwsAmazonSES do
  @moduledoc ~S"""
  An adapter that wraps `Swoosh.Adapters.AmazonSES` to use credentials from `ExAws`.

  You may prefer this adapter to `Swoosh.Adapters.AmazonSES` if you have already
  configured ExAws for your project and are using instance role credentials.

  This allows you to use automatically managed, short-lived credentials, rather than provisioning
  a static access key / secret key pair.

  See also:

  [IAM Roles for EC2](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/iam-roles-for-amazon-ec2.html)
  [IAM roles for ECS tasks](https://docs.aws.amazon.com/AmazonECS/latest/userguide/task-iam-roles.html)

  > ### Dependencies {: .info}
  >
  > In addition to the `:gen_smtp` dependency that the `AmazonSES` adapter
  > requires, this adapter also depends on `:ex_aws`.
  >
  > Ensure you have the dependencies added in your mix.exs file:
  >
  >     def deps do
  >       [
  >         {:swoosh, "~> 1.0"},
  >         {:gen_smtp, "~> 1.0"},
  >         {:ex_aws, "~> 2.1"},
  >         # Dependency of `:ex_aws`
  >         {:sweet_xml, "~> 0.6"}
  >       ]
  >     end

  ## Example

      # config/config.exs
      config :ex_aws,
        access_key_id: [{:system, "AWS_ACCESS_KEY_ID"}, :instance_role],
        secret_access_key: [{:system, "AWS_SECRET_ACCESS_KEY"}, :instance_role],
        region: "us-east-1"

      config :sample, Sample.Mailer,
        adapter: Swoosh.Adapters.ExAwsAmazonSES

      # lib/sample/mailer.ex
      defmodule Sample.Mailer do
        use Swoosh.Mailer, otp_app: :sample
      end

  See also:

  [Getting started with ExAws](https://hexdocs.pm/ex_aws/readme.html#getting-started)
  """

  use Swoosh.Adapter,
    required_deps: [gen_smtp: :mimemail, ex_aws: ExAws.Config],
    required_config: []

  alias Swoosh.Email
  alias Swoosh.Adapters.AmazonSES

  def deliver(%Email{} = email, config \\ []) do
    region_override = Keyword.get(config, :region)
    credentials = get_credentials(region_override)
    config = add_credentials(config, credentials)

    email
    |> add_security_token(credentials)
    |> AmazonSES.deliver(config)
  end

  defp get_credentials(nil), do: ExAws.Config.new(:ses)
  defp get_credentials(region), do: ExAws.Config.new(:ses, region: region)

  defp add_credentials(config, credentials) do
    Keyword.merge(
      [
        access_key: credentials.access_key_id,
        secret: credentials.secret_access_key,
        region: credentials.region
      ],
      config
    )
  end

  defp add_security_token(email, %{security_token: token}) do
    Email.put_provider_option(email, :security_token, token)
  end

  defp add_security_token(email, _), do: email
end
