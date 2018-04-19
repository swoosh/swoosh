defmodule Swoosh.MailerTest do
  use ExUnit.Case, async: true

  alias Swoosh.DeliveryError

  Application.put_env(
    :swoosh,
    Swoosh.MailerTest.FakeMailer,
    api_key: "api-key",
    domain: "avengers.com"
  )

  defmodule FakeAdapter do
    use Swoosh.Adapter

    def deliver(email, config), do: {:ok, {email, config}}
  end

  defmodule FakeMailer do
    use Swoosh.Mailer, otp_app: :swoosh, adapter: FakeAdapter
  end

  setup_all do
    valid_email = Swoosh.Email.new(
      from: "tony.stark@example.com",
      to: "steve.rogers@example.com",
      subject: "Hello, Avengers!",
      html_body: "<h1>Hello</h1>",
      text_body: "Hello"
    )
    {:ok, valid_email: valid_email}
  end

  test "dynamic adapter", %{valid_email: email} do
    defmodule OtherAdapterMailer do
      # Adapter not specified
      use Swoosh.Mailer, otp_app: :swoosh
    end

    assert {:ok, _} = OtherAdapterMailer.deliver(email, adapter: FakeAdapter)
  end

  if Version.match?(System.version(), "~> 1.5") do
    # TODO: Remove version guard when dropping Elixir 1.4 support
    # Elixir < 1.5 raises an unexpected error when on_load fails
    test "raise if mailer defined with nonexistent adapter", %{valid_email: email} do
      import ExUnit.CaptureLog

      assert capture_log(fn ->
        defmodule WontWorkAdapterMailer do
          use Swoosh.Mailer, otp_app: :swoosh, adapter: NotExistAdapter
        end
      end) =~ ~r/Elixir.NotExistAdapter does not exist/

      assert_raise UndefinedFunctionError, fn ->
        WontWorkAdapterMailer.deliver(email)
      end
    end
  end

  test "should raise if deliver!/2 is called with invalid from", %{valid_email: valid_email} do
    assert_raise DeliveryError, "delivery error: expected \"from\" to be set", fn ->
      Map.put(valid_email, :from, nil) |> FakeMailer.deliver!()
    end
    assert_raise DeliveryError, "delivery error: expected \"from\" to be set", fn ->
      Map.put(valid_email, :from, {"Name", nil}) |> FakeMailer.deliver!()
    end
    assert_raise DeliveryError, "delivery error: expected \"from\" to be set", fn ->
      Map.put(valid_email, :from, {"Name", ""}) |> FakeMailer.deliver!()
    end
  end

  test "config from environment variables", %{valid_email: email} do
    System.put_env("MAILER_TEST_SMTP_USERNAME", "userenv")
    System.put_env("MAILER_TEST_SMTP_PASSWORD", "passwordenv")

    Application.put_env(:swoosh, Swoosh.MailerTest.EnvMailer,
      [username: {:system, "MAILER_TEST_SMTP_USERNAME"},
       password: {:system, "MAILER_TEST_SMTP_PASSWORD"},
       relay: "smtp.sendgrid.net",
       tls: :always])

    defmodule EnvMailer do
      use Swoosh.Mailer, otp_app: :swoosh, adapter: FakeAdapter
    end

    {:ok, {_email, configs}} = EnvMailer.deliver(email)

    assert MapSet.subset?(
      MapSet.new([
        username: "userenv",
        password: "passwordenv",
        relay: "smtp.sendgrid.net",
        tls: :always
      ]),
      MapSet.new(configs)
    )
  end

  test "merge config passed to deliver/2 into Mailer's config", %{valid_email: email} do
    {:ok, {_email, configs}} = FakeMailer.deliver(email, domain: "jarvis.com")
    assert {:domain, "jarvis.com"} in configs
  end

  test "validate config passed to deliver/2", %{valid_email: email} do
    defmodule NoConfigAdapter do
      use Swoosh.Adapter, required_config: [:api_key]
      def deliver(_email, _config), do: {:ok, nil}
    end

    defmodule NoConfigMailer do
      use Swoosh.Mailer, otp_app: :swoosh, adapter: NoConfigAdapter
    end

    assert_raise ArgumentError, ~r/expected \[:api_key\] to be set/, fn ->
      NoConfigMailer.deliver(email, domain: "jarvis.com")
    end
  end

  test "raise when sending without an adapter configured", %{valid_email: email} do
    defmodule NoAdapterMailer do
      use Swoosh.Mailer, otp_app: :swoosh
    end

    assert_raise KeyError, ~r/:adapter not found/, fn ->
      NoAdapterMailer.deliver(email)
    end
  end
end
