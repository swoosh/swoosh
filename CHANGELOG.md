## Changelog

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
