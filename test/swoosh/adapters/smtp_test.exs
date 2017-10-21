defmodule Swoosh.Adapters.SMTPTest do
  use AdapterCase, async: true

  alias Swoosh.Adapters.SMTP

  setup_all do
    valid_config = [relay: "localhost"]

    {:ok, valid_config: valid_config}
  end

  test "validate_config/1 with valid config", %{valid_config: config} do
    assert SMTP.validate_config(config) == :ok
  end

  test "validate_config/1 with invalid config" do
    assert_raise ArgumentError, """
    expected [:relay] to be set, got: []
    """, fn ->
      SMTP.validate_config([])
    end
  end

  test "gen_smtp_config/1 enforces config date type" do
    assert MapSet.new(SMTP.gen_smtp_config([
      port: "2525",
      retries: "3",
      ssl: "true",
      tls: "always",
      auth: "if_available",
    ])) == MapSet.new([
      port: 2525,
      retries: 3,
      ssl: true,
      tls: :always,
      auth: :if_available,
    ])
  end

  import Swoosh.Email

  @email new()
    |> from("test@test.com")
    |> to("test@test.com")
    |> subject("test")
    |> text_body("test")

  test "gen_smtp_config/1 with invalid ssl config" do
    assert_raise ArgumentError, """
    ssl is not configured properly,
    got: INVALID, expected one of the followings:
    true, false
    """, fn ->
      SMTP.deliver(@email, [ssl: "INVALID"])
    end
  end

  test "gen_smtp_config/1 with invalid auth config" do
    assert_raise ArgumentError, """
    auth is not configured properly,
    got: INVALID, expected one of the followings:
    :always, :if_available
    """, fn ->
      SMTP.deliver(@email, [auth: "INVALID"])
    end
  end

  test "gen_smtp_config/1 with invalid tls config" do
    assert_raise ArgumentError, """
    tls is not configured properly,
    got: INVALID, expected one of the followings:
    :always, :never, :if_available
    """, fn ->
      SMTP.deliver(@email, [tls: "INVALID"])
    end
  end
end
