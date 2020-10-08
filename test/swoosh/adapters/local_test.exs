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

  test "deliver_many/1" do
    email_to_steve =
      Swoosh.Email.new(
        from: "tony.stark@example.com",
        to: "steve.rogers@example.com",
        subject: "Hello, Avengers!",
        text_body: "Hello!"
      )

    email_to_natasha =
      Swoosh.Email.new(
        from: "tony.stark@example.com",
        to: "natasha.romanoff@example.com",
        subject: "Hello, Avengers!",
        text_body: "Hello!"
      )

    {status, ids} = LocalMailer.deliver_many([email_to_steve, email_to_natasha])

    assert status == :ok
    assert Enum.count(ids) == 2
  end
end
