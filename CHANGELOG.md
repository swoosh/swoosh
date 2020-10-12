## Changelog

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
