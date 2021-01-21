## Changelog

## 1.2.1

### 🧰 Maintenance

- Export macros of `Swoosh.TestAssertions` as `locals_without_parens` for the formatter @LostKobrakai (#561)

## 1.2.0

### ✨ Features

- Add sendinblue adapter @tofran (#559)

### 🧰 Maintenance

- Bump hackney from 1.16.0 to 1.17.0 @dependabot (#557)

## 1.1.2

### 🐛 Bug Fixes

- fix gen_smtp 1.0 multipart @princemaple (#553)

### 🧰 Maintenance

- Bump mime from 1.4.0 to 1.5.0 @dependabot (#551)
- Bump bypass from 1.0.0 to 2.1.0 @dependabot (#550)

## 1.1.1

### ✨ Features

- Add support for arrays in mailgun custom_vars @rschef (#549)

### 🧰 Maintenance

- Utilize Enum.map_join/3 @tmock12 (#548)

## 1.1.0

Add `Swoosh.Email.Recipient` Protocl

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

## 1.0.9

Replace 1.0.8 which fell into a different bug

## 1.0.8

retired 1.0.7 which has compilation bug for users not having `gen_smtp` installed

### Bugfix

- Fix breaking change in `gen_smtp` 1.0 @gmile (#538)

### 🧰 Maintenance

- Bump ex_doc from 0.22.6 to 0.23.0 @dependabot (#534)

## 1.0.6

### ✨ Features

- Postmark: Add support for new broadcast email stream option @zorn (#533)
- Mailjet: short circuit deliver_many to prevent error when delivering 0 emails @Adzz (#532)

## 1.0.5

### Changes

Allow `:gen_smtp` 1.0

## 1.0.4

### 🚀 Features

- Use provider options to pass in security token @princemaple (#524)
- Add support for custom Content-Type header @princemaple (#522)
- Add support for temporary credentials in AmazonSES @riiwo (#518)

### 📝 Documentation

- Updates readme instructions for setting up layout @joshnuss (#517)
- Fix broken link to mailgun documentation @savtrip (#516)

## 1.0.3

### Changes

- Add CSRF token to dev preview mailbox (fixes #381) @DanielDent (#513)

## 1.0.2

### Added

- `deliver_many` implementation for TestAdapter (Thanks @Adzz, #503)

## 1.0.1

### Added

- Mailgun sending options, [see docs](https://hexdocs.pm/swoosh/Swoosh.Adapters.Mailgun.html)

## 1.0.0

Swoosh has been very stable for a very long time. It's about time, v1.0 is here.

## BREAKING

- Fixed return value for `Sendmail` [#483](https://github.com/swoosh/swoosh/pull/483)
  - before the fix its `deliver` implementation returns `:ok` but the Mailer behaviour requires it to return `{:ok, something}`, now it returns `{:ok, %{}}`

[Pre-1.0 changelogs](https://github.com/swoosh/swoosh/blob/pre-1.0/README.md)
