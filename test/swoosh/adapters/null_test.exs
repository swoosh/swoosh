defmodule Swoosh.Adapters.NullTest do
  use ExUnit.Case, async: true

  defmodule NullMailer do
    use Swoosh.Mailer, otp_app: :swoosh, adapter: Swoosh.Adapters.Null
  end

  test "deliver/1" do
    email = Swoosh.Email.new(from: "tony@stark.com",
                             to: "steve@rogers.com",
                             subject: "Hello, Avengers!",
                             text_body: "Hello!")

    assert {:ok, :null} = NullMailer.deliver(email)
  end
end
