defmodule Swoosh.Adapters.LocalTest do
  use ExUnit.Case, async: true

  defmodule LocalMailer do
    use Swoosh.Mailer, otp_app: :swoosh, adapter: Swoosh.Adapters.Local
  end

  test "deliver/1" do
    email = Swoosh.Email.new(from: "tony.stark@example.com",
                             to: "steve.rogers@example.com",
                             subject: "Hello, Avengers!",
                             text_body: "Hello!")
    {status, _} = LocalMailer.deliver(email)

    assert status == :ok
  end
end
