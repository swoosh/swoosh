defmodule Swoosh.MailerTest do
  use ExUnit.Case, async: true

  Application.put_env(:swoosh, Swoosh.MailerTest.FakeMailer,
    api_key: "api-key",
    domain: "avengers.com")

  defmodule FakeAdapter do
    def deliver(email, config), do: {email, config}
  end

  defmodule FakeMailer do
    use Swoosh.Mailer, otp_app: :swoosh, adapter: FakeAdapter
  end

  setup_all do
    valid_email = Swoosh.Email.new(from: "tony@stark.com",
                                   to: "steve@rogers.com",
                                   subject: "Hello, Avengers!",
                                   html_body: "<h1>Hello</h1>",
                                   text_body: "Hello")
    {:ok, valid_email: valid_email}
  end

  test "should raise if no adapter is specified" do
    assert_raise ArgumentError, fn ->
      defmodule NoAdapterMailer do
        use Swoosh.Mailer, otp_app: :swoosh
      end
    end
  end

  test "should raise if deliver/1 is not called with %Swoosh.Email{}" do
    assert_raise ArgumentError, "expected %Swoosh.Email{}, got nil", fn ->
      FakeMailer.deliver(nil)
    end
  end

  test "should raise if deliver/1 is called with invalid email", %{valid_email: valid_email} do
    assert_raise ArgumentError, "expected \"from\" to be set", fn ->
      Map.put(valid_email, :from, nil) |> FakeMailer.deliver()
    end
    assert_raise ArgumentError, "expected \"from\" address to be set", fn ->
      Map.put(valid_email, :from, {"Name", nil}) |> FakeMailer.deliver()
    end

    assert_raise ArgumentError, "expected \"to\" to be set", fn ->
      Map.put(valid_email, :to, nil) |> FakeMailer.deliver()
    end
    assert_raise ArgumentError, "expected \"to\" not to be empty", fn ->
      Map.put(valid_email, :to, []) |> FakeMailer.deliver()
    end

    assert_raise ArgumentError, "expected \"subject\" to be set", fn ->
      Map.put(valid_email, :subject, nil) |> FakeMailer.deliver()
    end

    assert_raise ArgumentError, "expected \"html_body\" or \"text_body\" to be set", fn ->
      valid_email
      |> Map.put(:html_body, nil)
      |> Map.put(:text_body, nil)
      |> FakeMailer.deliver()
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
      {email, [username: "userenv",
               password: "passwordenv",
               relay: "smtp.sendgrid.net",
               tls: :always]}
  end

  test "merge config passed to deliver/2 into Mailer's config", %{valid_email: email} do
    assert FakeMailer.deliver(email, domain: "jarvis.com") ==
      {email, [api_key: "api-key", domain: "jarvis.com"]}
  end
end
