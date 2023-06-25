# Swoosh

[![hex.pm](https://img.shields.io/hexpm/v/swoosh.svg)](https://hex.pm/packages/swoosh)
[![hex.pm](https://img.shields.io/hexpm/dt/swoosh.svg)](https://hex.pm/packages/swoosh)
[![hex.pm](https://img.shields.io/hexpm/l/swoosh.svg)](https://hex.pm/packages/swoosh)
[![github.com](https://img.shields.io/github/last-commit/swoosh/swoosh.svg)](https://github.com/swoosh/swoosh)

Compose, deliver and test your emails easily in Elixir.

Swoosh comes with many adapters, including SendGrid, Mandrill, Mailgun, Postmark and SMTP.
See the full list of [adapters below](#adapters).

The complete documentation for Swoosh is [available online at HexDocs](https://hexdocs.pm/swoosh).

## Requirements

Elixir 1.12+ and Erlang OTP 24+

## Getting started

```elixir
# In your config/config.exs file
config :sample, Sample.Mailer,
  adapter: Swoosh.Adapters.Sendgrid,
  api_key: "SG.x.x"
```

```elixir
# In your application code
defmodule Sample.Mailer do
  use Swoosh.Mailer, otp_app: :sample
end
```

```elixir
defmodule Sample.UserEmail do
  import Swoosh.Email

  def welcome(user) do
    new()
    |> to({user.name, user.email})
    |> from({"Dr B Banner", "hulk.smash@example.com"})
    |> subject("Hello, Avengers!")
    |> html_body("<h1>Hello #{user.name}</h1>")
    |> text_body("Hello #{user.name}\n")
  end
end
```

```elixir
# In an IEx session
email = Sample.UserEmail.welcome(%{name: "Tony Stark", email: "tony.stark@example.com"})
Sample.Mailer.deliver(email)
```

```elixir
# Or in a Phoenix controller
defmodule Sample.UserController do
  use Phoenix.Controller
  alias Sample.UserEmail
  alias Sample.Mailer

  def create(conn, params) do
    user = create_user!(params)

    UserEmail.welcome(user) |> Mailer.deliver()
  end
end
```

See [`Swoosh.Mailer`](https://hexdocs.pm/swoosh/Swoosh.Mailer.html) for more
configuration options.

## Installation

- Add swoosh to your list of dependencies in `mix.exs`:

  ```elixir
  def deps do
    [{:swoosh, "~> 1.11"}]
  end
  ```

- (Optional-ish) Most adapters (non SMTP ones) use `Swoosh.ApiClient` to talk
  to the service provider. Swoosh comes with `Swoosh.ApiClient.Hackney` configured
  by default. If you want to use it, you just need to include
  [`Hackney`](https://hex.pm/packages/hackney) as a dependency of your app.

  Swoosh also accepts [`Finch`](https://hex.pm/packages/finch) out-of-the-box.
  See `Swoosh.ApiClient.Finch` for details.

  If you need to integrate with another HTTP client, it's easy to define a new
  API client. Follow the `Swoosh.ApiClient` behaviour and configure Swoosh to
  use it:

  ```elixir
  config :swoosh, :api_client, MyApp.ApiClient
  ```

  But if you don't need `Swoosh.ApiClient`, you can disable it by setting the value
  to `false`:

  ```elixir
  config :swoosh, :api_client, false
  ```

  This is the case when you are using `Swoosh.Adapters.Local`,
  `Swoosh.Adapters.Test` and adapters that are SMTP based, that don't require
  an API client.

- (Optional) If you are using `Swoosh.Adapters.SMTP`,
  `Swoosh.Adapters.Sendmail` or `Swoosh.Adapters.AmazonSES`, you also need to
  add [`gen_smtp`](https://hex.pm/packages/gen_smtp) to your dependencies:

  ```elixir
  def deps do
    [
      {:swoosh, "~> 1.6"},
      {:gen_smtp, "~> 1.0"}
    ]
  end
  ```

## Adapters

Swoosh supports the most popular transactional email providers out of the box
and also has an SMTP adapter. Below is the list of the adapters currently
included:

| Provider     | Swoosh adapter                                                                                      |
| ------------ | --------------------------------------------------------------------------------------------------- |
| SMTP         | [Swoosh.Adapters.SMTP](https://hexdocs.pm/swoosh/Swoosh.Adapters.SMTP.html#content)                 |
| SendGrid     | [Swoosh.Adapters.Sendgrid](https://hexdocs.pm/swoosh/Swoosh.Adapters.Sendgrid.html#content)         |
| Brevo        | [Swoosh.Adapters.Brevo](https://hexdocs.pm/swoosh/Swoosh.Adapters.Brevo.html#content)               |
| Sendmail     | [Swoosh.Adapters.Sendmail](https://hexdocs.pm/swoosh/Swoosh.Adapters.Sendmail.html#content)         |
| Mandrill     | [Swoosh.Adapters.Mandrill](https://hexdocs.pm/swoosh/Swoosh.Adapters.Mandrill.html#content)         |
| Mailgun      | [Swoosh.Adapters.Mailgun](https://hexdocs.pm/swoosh/Swoosh.Adapters.Mailgun.html#content)           |
| Mailjet      | [Swoosh.Adapters.Mailjet](https://hexdocs.pm/swoosh/Swoosh.Adapters.Mailjet.html#content)           |
| Postmark     | [Swoosh.Adapters.Postmark](https://hexdocs.pm/swoosh/Swoosh.Adapters.Postmark.html#content)         |
| SparkPost    | [Swoosh.Adapters.SparkPost](https://hexdocs.pm/swoosh/Swoosh.Adapters.SparkPost.html#content)       |
| Amazon SES   | [Swoosh.Adapters.AmazonSES](https://hexdocs.pm/swoosh/Swoosh.Adapters.AmazonSES.html#content)       |
| Amazon SES   | [Swoosh.Adapters.ExAwsAmazonSES](https://hexdocs.pm/swoosh/Swoosh.Adapters.ExAwsAmazonSES.html)     |
| Dyn          | [Swoosh.Adapters.Dyn](https://hexdocs.pm/swoosh/Swoosh.Adapters.Dyn.html#content)                   |
| SocketLabs   | [Swoosh.Adapters.SocketLabs](https://hexdocs.pm/swoosh/Swoosh.Adapters.SocketLabs.html#content)     |
| Gmail        | [Swoosh.Adapters.Gmail](https://hexdocs.pm/swoosh/Swoosh.Adapters.Gmail.html#content)               |
| MailPace     | [Swoosh.Adapters.MailPace](https://hexdocs.pm/swoosh/Swoosh.Adapters.MailPace.html#content)         |
| SMTP2GO      | [Swoosh.Adapters.SMTP2GO](https://hexdocs.pm/swoosh/Swoosh.Adapters.SMTP2GO.html#content)           |
| ProtonBridge | [Swoosh.Adapters.ProtonBridge](https://hexdocs.pm/swoosh/Swoosh.Adapters.ProtonBridge.html#content) |

Configure which adapter you want to use by updating your `config/config.exs`
file:

```elixir
config :sample, Sample.Mailer,
  adapter: Swoosh.Adapters.SMTP
  # adapter config (api keys, etc.)
```

Check the documentation of the adapter you want to use for more specific
configurations and instructions.

Adding new adapters is super easy and we are definitely looking for
contributions on that front. Get in touch if you want to help!

## Recipient

The Recipient Protocol enables you to easily make your structs compatible
with Swoosh functions.

```elixir
defmodule MyUser do
  @derive {Swoosh.Email.Recipient, name: :name, address: :email}
  defstruct [:name, :email, :other_props]
end
```

Now you can directly pass `%MyUser{}` to `from`, `to`, `cc`, `bcc`, etc.
See `Swoosh.Email.Recipient` for more details.

## Async Emails

Swoosh does not make any special arrangements for sending emails in a
non-blocking manner. Opposite to some stacks, sending emails, talking
to third party apps, etc in Elixir do not block or interfere with other
requests, so you should resort to async emails only when necessary.

One simple way to deliver emails asynchronously is by leveraging Elixir's
standard library. First add a Task supervisor to your application root,
usually at `lib/my_app/application.ex`:

```elixir
def start(_, _) do
  children = [
    ...,
    # Before the endpoint
    {Task.Supervisor, name: MyApp.AsyncEmailSupervisor},
    MyApp.Endpoint
  ]

  Supervisor.start_link(children, strategy: :one_for_one)
end
```

Now, whenever you want to send an email:

```elixir
Task.Supervisor.start_child(MyApp.AsyncEmailSupervisor, fn ->
  %{name: "Tony Stark", email: "tony.stark@example.com"}
  |> Sample.UserEmail.welcome()
  |> Sample.Mailer.deliver()
end)
```

Please take a look at the official docs for
[Task](https://hexdocs.pm/elixir/Task.html) and
[Task.Supervisor](https://hexdocs.pm/elixir/Task.Supervisor.html) for further
options.

One of the downsides of sending email asynchronously is that failures won't
be reported to the user, who won't have an opportunity to try again immediately,
and tasks by default do not retry on errors. Therefore, if the email must be
delivered asynchronously, a safer solution would be to use a queue or job system.
Elixir's ecosystem has many
[job queue libraries](https://hex.pm/packages?search=job+queue&sort=recent_downloads).

- [Oban](https://hexdocs.pm/oban/Oban.html) is the current community favourite.
  It uses Post
