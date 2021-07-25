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

    def deliver_many(emails, config) do
      case Keyword.get(config, :force_error) do
        true -> {:error, {emails, config}}
        _ -> {:ok, {emails, config}}
      end
    end
  end

  defmodule FakeMailer do
    use Swoosh.Mailer, otp_app: :swoosh, adapter: FakeAdapter
  end

  setup_all do
    valid_email =
      Swoosh.Email.new(
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

  test "raise if mailer defined with nonexistent adapter", %{valid_email: email} do
    import ExUnit.CaptureLog

    assert capture_log(fn ->
             defmodule WontWorkAdapterMailer do
               use Swoosh.Mailer, otp_app: :swoosh, adapter: NotExistAdapter
             end

             refute function_exported?(WontWorkAdapterMailer, :deliver, 1)
             refute function_exported?(WontWorkAdapterMailer, :deliver, 2)
           end) =~ ~r/Elixir.NotExistAdapter does not exist/
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
      username: {:system, "MAILER_TEST_SMTP_USERNAME"},
      password: {:system, "MAILER_TEST_SMTP_PASSWORD"},
      relay: "smtp.sendgrid.net",
      tls: :always
    )

    defmodule EnvMailer do
      use Swoosh.Mailer, otp_app: :swoosh, adapter: FakeAdapter
    end

    {:ok, {_email, configs}} = EnvMailer.deliver(email)

    assert MapSet.subset?(
             MapSet.new(
               username: "userenv",
               password: "passwordenv",
               relay: "smtp.sendgrid.net",
               tls: :always
             ),
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

  test "validate dependency" do
    defmodule FakeDepAdapter do
      use Swoosh.Adapter, required_deps: [VillanModule, v_dep: VModule]
      def deliver(_, _), do: :ok
    end

    import ExUnit.CaptureLog

    error =
      capture_log(fn ->
        assert :abort = Swoosh.Mailer.validate_dependency(FakeDepAdapter)
      end)

    assert error =~ "- VillanModule"
    assert error =~ "- Elixir.VModule from :v_dep"
  end

  test "deliver/2 outputs telemetry event on success", %{valid_email: email} do
    handler = fn event, %{}, metadata, _ ->
      send(self(), {:telemetry, event, metadata})
    end

    assert :ok = :telemetry.attach("deliver-success", [:swoosh, :sent, :success], handler, nil)
    assert {:ok, _} = FakeMailer.deliver(email)
    assert_receive {:telemetry, [:swoosh, :sent, :success], %{mailer: FakeMailer}}
  end

  test "deliver/2 outputs telemetry event on error", %{valid_email: email} do
    handler = fn event, %{}, metadata, _ ->
      send(self(), {:telemetry, event, metadata})
    end

    assert :ok = :telemetry.attach("deliver-error", [:swoosh, :sent, :failure], handler, nil)
    assert {:error, _} = Map.put(email, :from, nil) |> FakeMailer.deliver()
    assert_receive {:telemetry, [:swoosh, :sent, :failure], %{mailer: FakeMailer}}
  end

  test "deliver_many/2 outputs telemetry event on success", %{valid_email: email} do
    handler = fn event, %{}, metadata, _ ->
      send(self(), {:telemetry, event, metadata})
    end

    assert :ok =
             :telemetry.attach(
               "delivery-many-success",
               [:swoosh, :sent_many, :success],
               handler,
               nil
             )

    assert {:ok, _} = FakeMailer.deliver_many([email, email], [])
    assert_receive {:telemetry, [:swoosh, :sent_many, :success], %{mailer: FakeMailer, count: 2}}
  end

  test "deliver_many/2 outputs telemetry event on error", %{valid_email: email} do
    handler = fn event, %{}, metadata, _ ->
      send(self(), {:telemetry, event, metadata})
    end

    assert :ok =
             :telemetry.attach(
               "deliver-many-error",
               [:swoosh, :sent_many, :failure],
               handler,
               nil
             )

    assert {:error, _} = FakeMailer.deliver_many([email, email], force_error: true)
    assert_receive {:telemetry, [:swoosh, :sent_many, :failure], %{mailer: FakeMailer, count: 2}}
  end
end
