defmodule Swoosh.Integration.Adapters.PostmarkTest do
  use ExUnit.Case, async: true

  import Swoosh.Email

  @moduletag integration: true

  setup_all do
    config = [api_key: System.get_env("POSTMARK_API_KEY")]
    {:ok, config: config}
  end

  test "simple deliver", %{config: config} do
    email =
      new
      |> from({"Swoosh Postmark", "swoosh@elixirhq.com"})
      |> reply_to("swoosh+replyto@elixirhq.com")
      |> to("swoosh+to@elixirhq.com")
      |> cc("swoosh+cc@elixirhq.com")
      |> bcc("swoosh+bcc@elixirhq.com")
      |> subject("Swoosh - Postmark integration test")
      |> text_body("This email was sent by the Swoosh library automation testing")
      |> html_body("<p>This email was sent by the Swoosh library automation testing</p>")

    assert {:ok, _response} = Swoosh.Adapters.Postmark.deliver(email, config)
  end
end
