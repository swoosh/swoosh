## Changelog

### 1.0.1

### Added

- Mailgun sending options, [see docs](https://hexdocs.pm/swoosh/Swoosh.Adapters.Mailgun.html)

### 1.0.0

Swoosh has been very stable for a very long time. It's about time, v1.0 is here.

## BREAKING

- Fixed return value for `Sendmail` [#483](https://github.com/swoosh/swoosh/pull/483)
  - before the fix its `deliver` implementation returns `:ok` but the Mailer behaviour requires it to return `{:ok, something}`, now it returns `{:ok, %{}}`

[Pre-1.0 changelogs](https://github.com/swoosh/swoosh/blob/pre-1.0/README.md)
