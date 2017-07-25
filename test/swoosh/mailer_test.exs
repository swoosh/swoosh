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

  test "should raise if no adapter is specified" do
    assert_raise ArgumentError, fn ->
      defmodule NoAdapterMailer do
        use Swoosh.Mailer, otp_app: :swoosh
      end
    end
  end

  test "dynamic adapter", %{valid_email: email} do
    defmodule OtherAdapterMailer do
      use Swoosh.Mailer, otp_app: :swoosh, adapter: NotExistAdapter
    end

    assert {:ok, _} = OtherAdapterMailer.deliver(email, adapter: FakeAdapter)
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

    assert EnvMailer.deliver(email) ==
      {:ok, {email, [
        username: "userenv",
        password: "passwordenv",
        relay: "smtp.sendgrid.net",
        tls: :always
      ]}}
  end

  test "merge config passed to deliver/2 into Mailer's config", %{valid_email: email} do
    assert FakeMailer.deliver(email, domain: "jarvis.com") ==
      {:ok, {email, [api_key: "api-key", domain: "jarvis.com"]}}
  end

  test "validate config passed to deliver/2", %{valid_email: email} do
    defmodule NoConfigAdapter do
      use Swoosh.Adapter, required_config: [:api_key]
      def deliver(_email, _config), do: {:ok, nil}
    end

    defmodule NoConfigMailer do
      use Swoosh.Mailer, otp_app: :swoosh, adapter: NoConfigAdapter
    end

    assert_raise ArgumentError, """
    expected [:api_key] to be set, got: [domain: "jarvis.com"]
    """, fn ->
      NoConfigMailer.deliver(email, domain: "jarvis.com")
    end
  end
end
