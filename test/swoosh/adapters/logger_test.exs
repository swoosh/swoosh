defmodule Swoosh.Adapters.LoggerTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  defmodule LoggerMailer do
    use Swoosh.Mailer, otp_app: :swoosh, adapter: Swoosh.Adapters.Logger
  end

  setup_all do
    email = Swoosh.Email.new(
      from: "tony@stark.com",
      to: "steve@rogers.com",
      subject: "Hello, Avengers!",
      text_body: "Hello!"
    )
    {:ok, email: email}
  end

  test "deliver/1", %{email: email} do
    assert capture_log(fn ->
      {status, _} = LoggerMailer.deliver(email)
      assert status == :ok
    end) =~ "New email delivered to steve@rogers.com"
  end

  test "deliver/1, log full email", %{email: email} do
    assert capture_log(fn ->
      {status, _} = LoggerMailer.deliver(email, log_full_email: true)
      assert status == :ok
    end) =~ "New email delivered\nFrom: tony@stark.com"
  end
end
