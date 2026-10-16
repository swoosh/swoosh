defmodule Swoosh.Adapters.SendmailTest do
  use Swoosh.AdapterCase, async: true

  import ExUnit.CaptureLog
  import Swoosh.Email
  alias Swoosh.Adapters.Sendmail

  setup_all do
    valid_email =
      new()
      |> from("tony.stark@example.com")
      |> to("steve.rogers@example.com")
      |> subject("Hello, Avengers!")
      |> html_body("<h1>Hello</h1>")
      |> text_body("Hello")

    valid_config = [
      adapter: Swoosh.Adapters.Sendmail,
      cmd_path: "/usr/bin/sendmail",
      cmd_args: ["-N", "delay,failure,success"]
    ]

    {:ok, valid_email: valid_email, valid_config: valid_config}
  end

  test "cmd_path", %{valid_config: config} do
    assert Sendmail.cmd_path(config) == config[:cmd_path]
    config = Keyword.delete(config, :cmd_path)
    assert Sendmail.cmd_path(config) == "/usr/sbin/sendmail"
    config = config ++ [qmail: true]
    assert Sendmail.cmd_path(config) == "/var/qmail/bin/qmail-inject"
  end

  test "cmd_args", %{valid_email: email, valid_config: config} do
    assert Sendmail.cmd_args(email, config) ==
             ["-f", "tony.stark@example.com", "-oi", "-t"] ++ config[:cmd_args]

    config = config ++ [qmail: true]

    assert Sendmail.cmd_args(email, config) ==
             ["-f", "tony.stark@example.com"] ++ config[:cmd_args]

    config = Keyword.delete(config, :cmd_args)
    assert Sendmail.cmd_args(email, config) == ["-f", "tony.stark@example.com"]
    config = Keyword.delete(config, :qmail)
    assert Sendmail.cmd_args(email, config) == ["-f", "tony.stark@example.com", "-oi", "-t"]
  end

  test "string cmd_args", %{valid_email: email} do
    {result, log} =
      with_log(fn ->
        Sendmail.cmd_args(email, %{cmd_args: "abc def"})
      end)

    assert result == ["-f", "tony.stark@example.com", "-oi", "-t", "abc", "def"]
    assert log =~ "Deprecated"
  end
end
