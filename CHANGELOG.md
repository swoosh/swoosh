# Changelog

## 1.8.2

### ✨ Features

- Swoosh.Adapters.Test.delivery\_many/2 returns a list @markthequark (#721)

### 📝 Documentation

- Add missing double quote to mandrill template content sample @alvarezloaiciga (#726)

### 🧰 Maintenance

- Bump ex\_doc from 0.28.5 to 0.29.0 @dependabot (#725)

## 1.8.1

### ✨ Features

- Postmark: Support per email tracking options @Wijnand (#722)

### 🧰 Maintenance

- Bump jason from 1.3.0 to 1.4.0 @dependabot (#719)

## 1.8.0

### ✨ Features

- Prevent crashes caused by the memory GenServer restarts @KiKoS0 (#717)

### 🧰 Maintenance

- Bump ex\_aws from 2.3.4 to 2.4.0 @dependabot (#715)

## 1.7.5

Bump to require Elixir 1.11. Now official support has been updated to Elixir 1.11+ with OTP 23+

## 📝 Documentation

- doc: correct tags example for Adapters.Sendinblue @03juan (#711)

## 🧰 Maintenance

- Bump ex\_doc from 0.28.4 to 0.28.5 @dependabot (#712)
- Bump ex\_aws from 2.3.3 to 2.3.4 @dependabot (#710)

## 1.7.4

### ✨ Features

- Set attachment's ContentId in Mailjet @marcinkoziej (#709)

### 🧰 Maintenance

- Bump mime from 2.0.2 to 2.0.3 @dependabot (#708)
- Bump finch from 0.12.0 to 0.13.0 @dependabot (#707)

### 📝 Documentation

- Fix typos in gmail and socket labs adapters @zusoomro (#706)
- Fix markdown issues and typos @kianmeng (#705)

## 1.7.3

### ✨ Features

- Support assertions for headers @MatheusBuss (#702)

## 1.7.2

### ✨ Features

- add schedule\_at provider param for sendinblue @moperacz (#700)

### 📝 Documentation

- Update Telemetry example to mention errors on `:stop` @lucasmazza (#698)

### 🧰 Maintenance

- Bump ex\_aws from 2.3.2 to 2.3.3 @dependabot (#699)

## 1.7.1

### ✨ Features

- sendgrid add support for scheduling emails @shravanjoopally (#696)

### 🧰 Maintenance

- Test otp 25 @princemaple (#695)

## 1.7.0

### ✨ Features

- SMTP: Allow send email without 'To' @Danielwsx64 (#694)
- Add SMTP2GO adapter @princemaple (#687)

### 🧰 Maintenance

- Bump ex\_aws from 2.3.1 to 2.3.2 @dependabot (#692)
- Bump finch from 0.11.0 to 0.12.0 @dependabot (#690)
- Bump ex\_doc from 0.28.3 to 0.28.4 @dependabot (#688)

### 📝 Documentation

- fix module name in ExAwsAmazonSES module doc @SteffenDE (#689)

## 1.6.6

- Suppress warning about `ExAws.Config` introduced in 1.6.5 as optional dependency

## 1.6.5

- Add `Swoosh.Adapters.ExAwsAmazonSES` adapter @ascandella (#684)

### 🧰 Maintenance

- Bump gen_smtp from 1.1.1 to 1.2.0 @dependabot (#682)

## 1.6.4

- Add message_stream documentation to Postmark adapter @ntodd (#674)
- Rename Mime-Version header to MIME-Version @tcitworld (#681)

## 1.6.3

- Migrate OhMySmtp to Mailpace @princemaple (#672)

## 1.6.2

- SMTP can now utilize the new `:cid` addition in attachments, if `:cid` is
  `nil` it will fallback to original behavior and use `:filename`
- Fixed filename for inline images sent via SMTP

## 1.6.1

- Add fields to Postmark `deliver_many` response @zporter (#668)

## 1.6.0

### ✨ Features

- allow custom CIDs for inline attachments @taobojlen (#665)
- add OhMySMTP adapter @taobojlen (#663)

### 🧰 Maintenance

- Bump finch from 0.10.1 to 0.10.2 @dependabot (#661)
- Bump ex_doc from 0.27.0 to 0.27.3 @dependabot (#660)
- Bump ex_doc from 0.26.0 to 0.27.0 @dependabot (#659)
- Bump finch from 0.10.0 to 0.10.1 @dependabot (#655)
- Bump jason from 1.2.2 to 1.3.0 @dependabot (#654)
- Bump finch from 0.9.1 to 0.10.0 @dependabot (#651)
- Config bypass only on test @nallwhy (#650)

### 📝 Documentation

- Mention E2E tests @princemaple (#664)
- Add configuration options to Mailgun documentation @Zurga (#652)
- Add example to Dyn adapter @kianmeng (#647)
- Add provider options for Sparkpost @kianmeng (#646)
- Add provider options doc for socketlabs @kianmeng (#645)
- Update provider options doc for Sendinblue @kianmeng (#644)
- Update provider options doc for Sendgrid @kianmeng (#643)
- Update provider options doc for Postmark @kianmeng (#642)
- Add provider options doc for Mandrill adapter @kianmeng (#641)
- Add provider options doc for Mailjet @kianmeng (#640)
- Update provider options doc for Mailgun adapter @kianmeng (#639)
- Add provider options doc for Amazon SES adapter @kianmeng (#638)
- Correct sample configuration for gmail adapter @aarongraham (#637)
- Clarify that you need to add :gen_smtp as a dependency @Hermanverschooten (#635)

### New Contributors

- @Hermanverschooten made their first contribution in https://github.com/swoosh/swoosh/pull/635
- @aarongraham made their first contribution in https://github.com/swoosh/swoosh/pull/637
- @nallwhy made their first contribution in https://github.com/swoosh/swoosh/pull/650
- @Zurga made their first contribution in https://github.com/swoosh/swoosh/pull/652
- @taobojlen made their first contribution in https://github.com/swoosh/swoosh/pull/663

**Full Changelog**: https://github.com/swoosh/swoosh/compare/v1.5.2...v1.6.0

## 1.5.2

### Fixes

- Fix closing tag @feld (#634)

## 1.5.1

### ✨ Features

- Adding support for inline attachments preview in MailboxPreview @theodowling (#628)

### 📝 Documentation

- Fixing Typo @Orijhins (#629)
- Further cleanup async section @josevalim (#621)
- Build upon async emails section @josevalim (#620)
- Fix typos @kianmeng (#618)
- Fix a few typos in the docs @nickjj (#617)

## 1.5.0

### ✨ Features

- Add telemetry to `Mailer.deliver` \& `Mailer.deliver_many` @joshnuss (#614)

### 📝 Documentation

- Improve README.md - mention `api_client` as false @philss (#610)

## 1.4.0

### Add `Swoosh.ApiClient.Finch`

You can configure what API Client to use by setting the config. Swoosh comes with
`Swoosh.ApiClient.Hackney` and `Swoosh.ApiClient.Finch`

```elixir
config :swoosh, :api_client, MyAPIClient
```

It defaults to use `:hackney` with `Swoosh.ApiClient.Hackney`. To use `Finch`,
add the below config

```elixir
config :swoosh, :api_client, Swoosh.ApiClient.Finch
```

To use `Swoosh.ApiClient.Finch` you also need to start `Finch`, either in your
supervision tree

```elixir
children = [
  {Finch, name: Swoosh.Finch}
]
```

or somehow manually, and very rarely dynamically

```elixir
Finch.start_link(name: Swoosh.Finch)
```

If a name different from `Swoosh.Finch` is used, or you want to use an existing
Finch instance, you can provide the name via the config.

```elixir
config :swoosh,
  api_client: Swoosh.ApiClient.Finch,
  finch_name: My.Custom.Name
```

[Pre-1.4 changelogs](https://github.com/swoosh/swoosh/blob/v1.3.11/CHANGELOG.md)
