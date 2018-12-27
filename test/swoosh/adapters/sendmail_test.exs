defmodule Swoosh.Adapters.SendmailTest do
  use Swoosh.AdapterCase, async: true

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
      cmd_args: "-N delay,failure,success"
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

  test "cmd_args", %{valid_config: config} do
    assert Sendmail.cmd_args(config) == " -oi -t " <> config[:cmd_args]
    config = config ++ [qmail: true]
    assert Sendmail.cmd_args(config) == " " <> config[:cmd_args]
    config = Keyword.delete(config, :cmd_args)
    assert Sendmail.cmd_args(config) == ""
    config = Keyword.delete(config, :qmail)
    assert Sendmail.cmd_args(config) == " -oi -t"
  end

  test "cmd", %{valid_email: email, valid_config: config} do
    cmd = "#{config[:cmd_path]} -f'tony.stark@example.com' -oi -t #{config[:cmd_args]}"
    assert Sendmail.cmd(email, config) == cmd
  end
end
