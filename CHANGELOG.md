## Changelog

## v0.16.0 - 2018-07-26

### Added

- Support for Mailgun tags ([#256](https://github.com/swoosh/swoosh/pull/256), thanks! @DavidOliver)
- Allow cowboy2 in dependency ([#260](https://github.com/swoosh/swoosh/pull/260), thanks! @hl)

## v0.15.0 - 2018-06-15

### Added

- Expose Attachments in Mailbox Preview ([#245](https://github.com/swoosh/swoosh/pull/245), thanks! @maennchen)

![preview](https://user-images.githubusercontent.com/333918/40985860-3d0c6d66-68e5-11e8-8a31-87730b96d245.png)

### Changed

- Switchig from listing `applications` to `extra_applications`
  - less error-prone
  - fix `:jason` application not available in releases

## v0.14.0 - 2018-05-18

### Added

* SMTP Adapter now accepts `:no_mx_lookups` option ([#203](https://github.com/swoosh/swoosh/pull/203), thanks @sergioaugrod)
* Support of metadata for Mandrill ([#208](https://github.com/swoosh/swoosh/pull/208), thanks @chubarovNick)
* Add SendGrid asm field ([#221](https://github.com/swoosh/swoosh/pull/221), thanks @nathf)
* Support regex match on html and text body in TestAssertion ([#229](https://github.com/swoosh/swoosh/pull/229), thanks @michallepicki)
* Support of template alias for Postmark ([#232](https://github.com/swoosh/swoosh/pull/232), thanks @sebastianseilund)
* Display provider_options in mailbox_viewer ([#234](https://github.com/swoosh/swoosh/pull/234), thank you @sebastianseilund again!)

### Changed

* Poison -> Jason (Also making json library configurable, [#214](https://github.com/swoosh/swoosh/pull/214), [#216](https://github.com/swoosh/swoosh/pull/216))
* All modules are now defined regardless of whether their dependencies exist, warnings are suppressed via `xref: [exclude: [...]]`, compile time checks are put in place ([#219](https://github.com/swoosh/swoosh/pull/219))

```
> iex -S mix
Compiling 1 file (.ex)

06:02:24.569 [error] The following dependencies are required to use Swoosh.Adapters.SMTP:

- gen_smtp_client from :gen_smtp
```

### Fixed

* Sending text only email with SparkPost ([#207](https://github.com/swoosh/swoosh/pull/207), fixed in [#210](https://github.com/swoosh/swoosh/pull/210))

## v0.13.0 - 2018-01-18

### Added

* **New Adapter** Dyn ([#188](https://github.com/swoosh/swoosh/pull/188), thanks! @jann)
* Return message id from Sendgrid Adapter ([#189](https://github.com/swoosh/swoosh/pull/189, thanks! @felipesere)
* Support handling recipient variables in Mailgun Adapter ([#194](https://github.com/swoosh/swoosh/pull/194), thanks! @messutied)

## v0.12.1 - 2018-01-05

### Fixed

* Fix date header formatting in Amazon SES adapter. ([#190](https://github.com/swoosh/swoosh/pull/190))

## v0.12.0 - 2017-12-13

### Added

* Mandrill template and variable interpolation support ([#172](https://github.com/swoosh/swoosh/pull/172) - thanks and congrats on your first Elixir PR @sescobb27)
* Support optional attachment headers in SMTP related Adapters ([#176](https://github.com/swoosh/swoosh/pull/176) - thanks! @davec82)
* Support in-memory attachment ([#178](https://github.com/swoosh/swoosh/pull/178) - thanks again! @davec82, and [#182](https://github.com/swoosh/swoosh/pull/182))

### Fixed

* Dialyzer warnings ([#180](https://github.com/swoosh/swoosh/pull/180) thanks! @xadhoom)
* Alternative multipart email with attachment shows both text and html content ([#184](https://github.com/swoosh/swoosh/pull/184) thanks again! @xadhoom)
* Fix warning in Amazon SES adapter when `mimemail` dependency is not loaded. ([#187](https://github.com/swoosh/swoosh/pull/184))

## v0.11.0 - 2017-11-01

### Added

* Inline attachment support in all adapters! ([#159](https://github.com/swoosh/swoosh/pull/159) - many thanks to @theodowling)
* Injected Mailer functions now come with typespecs ([#158](https://github.com/swoosh/swoosh/pull/158))
* Amazon SES Adapter! ([#167](https://github.com/swoosh/swoosh/pull/167) - great work by @jdollar, thank you!)

### Fixed

* SMTP configs are now checked and parsed to appropriate types if passed in as strings ([#162](https://github.com/swoosh/swoosh/pull/162))
* Mandrill Adapter error handling. (Detailed report in [#168](https://github.com/swoosh/swoosh/issues/168), fixed in [#169](https://github.com/swoosh/swoosh/pull/169))

## v0.10.0 - 2017-09-13

### Added

* Add support for custom email headers in all adapters that were missing it: Postmark, Sendgrid, Mandrill and Sparkpost.
([#155](https://github.com/swoosh/swoosh/pull/155))

## v0.9.1 - 2017-08-16

### Fixed
* Quote name portion of recipient in Mailgun adapter. ([#150](https://github.com/swoosh/swoosh/pull/150))

## v0.9.0 - 2017-08-04

### Changed

* Simplify `Swoosh.TestAssertions.assert_email_sent/1` ([#139](https://github.com/swoosh/swoosh/pull/139)):
  * to cope with different AST in different Elixir versions
  * to take advantage of ExUnit colored diffs
* Swoosh no longer reads config at compile time. ([#146](https://github.com/swoosh/swoosh/pull/146))
* Require `Elixir ~> 1.4` so that we can take advantage of all the OTP20 features.
* Bump [plug](https://github.com/elixir-lang/plug) to 1.4.3.
* Bump [hackney](https://github.com/benoitc/hackney) to 1.9.0.

## v0.8.1 - 2017-06-10

### Added

* Warn when failing to start the preview server ([#130](https://github.com/swoosh/swoosh/pull/130))
* Support for mail headers in Mailgun adapter ([#134](https://github.com/swoosh/swoosh/pull/134))
* Allow adding attachments in Email.new ([#135](https://github.com/swoosh/swoosh/pull/135))

## v0.8.0 - 2017-05-06

### Added
* Add support for attachments.
* Add support for [categories](https://sendgrid.com/docs/API_Reference/api_v3.html) in the Sendgrid adapter

### Changed
* Bump [plug](https://github.com/elixir-lang/plug) to 1.3.5.
* Bump [hackney](https://github.com/benoitc/hackney) to 1.8.0.

## v0.7.0 - 2017-03-14

### Added
* Add [SparkPost](https://www.sparkpost.com) adapter.

### Changed
* Bump [poison](https://github.com/devinus/poison) to 3.1.
* Bump [plug](https://github.com/elixir-lang/plug) to 1.3.3.
* Bump [hackney](https://github.com/benoitc/hackney) to 1.7.1.

## v0.6.0 - 2017-02-13

### Added
* The Sendgrid adapter now supports server-side templates and substitutions.

### Changed
* Cowboy dependency was relaxed to ~> 1.0 (from ~> 1.0.0).
* Load Sendmail and SMTP.Helpers if :mimemail is loaded.

### Fixed
* Fix compiler warnings for Elixir 1.4.

## v0.5.0 - 2016-10-19

### Added
* The Mailgun adapter now supports [attaching data](https://documentation.mailgun.com/user_manual.html#attaching-data-to-messages) to emails.
* The Postmark adapter now supports using [server-side templates](http://developer.postmarkapp.com/developer-api-templates.html#email-with-template).

### Changed
* The Sendgrid adapter now uses the [Sendgrid v3 API](https://sendgrid.com/docs/API_Reference/Web_API_v3/Mail/index.html).
* `gen_stmp` is now an optional dependency.
* Drop HTTPoison in favor of hackney.
* Enlarge the message area in the preview Plug.
* Bump [poison](https://github.com/devinus/poison) to 3.0.
* Bump [plug](https://github.com/elixir-lang/plug) to 1.2.

### Fixed
* The SMTP and Sendmail adapters now correctly set the `Bcc` header.
* The Postmark adapter now respects the `From` name.
* Replace `:crypt.rand_bytes/1` by `:crypto.strong_rand_bytes/1` since it was deprecated with OTP 19.

## v0.4.0 - 2016-06-25

This version contains a couple of breaking changes, mostly due to the introduction of a `deliver!/2` (see below):
* API-based adapter will now return a slightly different error payload: `{:error, {status_code, payload}}` instead of
`{:error, body}`
* `deliver/2` will no longer raise if the email validation failed.
* We now only validate that the `From` address is present, according to the RFC 5322. This is the lowest common
deminotar across all our adapters. This means we will **NO** longer check that a recipient is present (`to`, `cc`, `bcc`),
that the subject is set, or that either of `html_body` or `text_body` is set.

### Added
* Add Sendmail adapter.
* Add a new `deliver!/2` function that will raise in case of an API or SMTP error, or if the email validation failed. In
that case a `Swoosh.DeliveryError` will be raised.
* Add Logger adapter. This can be useful when you don't want to send real emails but still want to know that the email
has been sent sucessfully.
* Add DKIM support for the SMTP and Sendmail adapter.
* Add basic integration testing. We are now making real calls to the various providers' API during testing (except Mandrill).

### Changed
* Raise on missing adapter config.
* Refactor `Swoosh.Adapters.Local` to support configurable storage drivers. For now, only memory storage has been
implemented.
* Generate case-insentitive Message-IDs in `Swoosh.Adapters.Local.Storage.Memory`. This was previously breaking endpoint
with lowercase path rewrite.
* Move email validation logic to base mailer. We also change the validation to follow the RFC and we now only check that
a `From` email address is set.
* Bump [gen_smtp](https://github.com/Vagabond/gen_smtp) to 0.11.0.

### Fixed
* Show the actual port `Plug.Swoosh.MailboxPreview` is binding on.
* Add [poison](https://github.com/devinus/poison) to the list of applications in the `mix.exs` file.
* Handle 401 response for Mailgun properly. It's a text response so we don't try to JSON decode it anymore.

### Removed
* `Swoosh.InMemoryMailbox` has been removed in favor of `Swoosh.Adapters.Local.Storage.Memory`. If you were using that
module directly you will need to update any reference to it.

## v0.3.0 - 2016-04-20
### Added
* Add `Swoosh.Email.new/1` function to create `Swoosh.Email{}` struct.
* `Swoosh.TestAssertions.assert_email_sent/1` now supports asserting on specific email params.

### Changed
* Remove the need for `/` when setting the Mailgun adapter domain config.
* `Plug.Swoosh.MailboxPreview` now formats email fields in a more friendlier way.

### Fixed
* Use the sender's name in the `From` header with the Mailgun adapter.
* Send custom headers set in `%Swoosh.Email{}.headers` when using the SMTP adapter.
* Use the "Sender" header before the "From" header as the "MAIL FROM" when using the SMTP adapter.

## [v0.2.0] - 2016-03-31
### Added
* Add support for runtime configuration using `{:system, "ENV_VAR"}` tuples
* Add support for passing config as an argument to deliver/2

### Changed
* Adapters have consistent successful return value (`{:ok, term}`)
* Only compile `Plug.Swoosh.MailboxPreview` if `Plug` is loaded
* Relax Poison version requirement (`~> 1.5 or ~> 2.0`)

### Removed
* Remove `cowboy` and `plug` from the list of applications as they are optional
dependencies

## [v0.1.0]

* Initial version
