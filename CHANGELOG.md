# Changelog

## 1.19.8

### ✨ Features

- Encode international domain names (IDNA) @jiegillet (#1070)

## 1.19.7

### 🐛 Bug Fixes

- Fix special "TEMPLATE" from option in CustomerIO adapter @maltoe (#1069)

## 1.19.6

### ✨ Features

- Add Lettermint adapter @olivermt (#1064)

## 1.19.5

### 🐛 Bug Fixes

- Support rendering `"TEMPLATE"` in the mailbox @axelson (#1059)

## 1.19.4

### ✨ Features

- Allow Customer.io to use `"TEMPLATE"` for from @axelson (#1058)

## 1.19.3

### ✨ Features

- Add deliver\_many support to Brevo adapter @linusdm (#1049)

## 1.19.2

### ✨ Features

- Escape quotes and backslashes in address names @jiegillet (#1047)
- Add Accept header to all requests made by Sendgrid adapter @sergey-elkin (#1046)
- Remove svg fill for dark mode @cmnstmntmn (#1044)

### 🧰 Maintenance

- Fix unused variable warnings in CI - Gmail Test @DuldR (#1045)

## 1.19.1

### 🐛 Bug Fixes

- Regenerate styles, fix [#1030](https://github.com/swoosh/swoosh/issues/1030)

## 1.19.0

### ✨ Features

- Redirect to latest message in mailbox if one exists @chrismccord (#1032)
- make links clickable in text email preview @SteffenDE (#1031)

### 🐛 Bug Fixes

- Specify the correct content\_disposition and content\_id @Hermanverschooten (#901)
  - fixes Mua adapter when using inline attachments

## 1.18.4

### ✨ Features

- Support dark/light mode based on system theme in dev preview mailbox @chrismccord (#1027)

## 1.18.3

### 🧰 Maintenance

- Update Req usage, preparing for v1.0 @wojtekmach (#1022)

## 1.18.2

### 🐛 Bug Fixes

- Fix: Prevent zeptomail error when receiving non json response body on 500 @atoncetti (#1017)

## 1.18.1

### ✨ Features

- Add PostUp adapter @zatchheems (#1015)

## 1.18.0

### ✨ Features

- Implement loops.so adapter @caioaao (#1012)

## 1.17.10

### 🐛 Bug Fixes

- Fix broken attachments on Scaleway adapter @olivermt (#1003)

## 1.17.9

### 🐛 Bug Fixes

- fix assets path prefix
- improve static serving config

## 1.17.8 (deprecated: broken css priv path, fixed in 1.17.9)

### 🐛 Bug Fixes

- fix priv path for css file @princemaple (#1001)

## 1.17.7 (deprecated: broken css priv path, fixed in 1.17.9)

### ✨ Feature

- fix: add csp nonce @yordis (#996)

### 🧰 Maintenance

- Compile tailwind instead of using cdn @princemaple (#998)

## 1.17.6

### ✨ Features

- Sendgrid: Support Mail Body Compression @luhagel (#971)

### 📝 Documentation

- Document how to change base\_url for CustomerIO adapter @sheharyarn (#987)
- Add JSON section to README @princemaple (#985)
- Fix doc typo in test\_assertions.ex @sevab (#983)

## 1.17.5

This release fixes a bug introduced in 1.17.4

### 🐛 Bug Fixes

- mua: fix mail.from @ruslandoga (#982)

### 📝 Documentation

- Adapters: Add documentation about setting the base\_url for ZeptoMail … @reimeri (#981)

## 1.17.4

### 🐛 Bug Fixes

- mua: fix default message-id @ruslandoga (#978)

### 🧰 Maintenance

- mua: cleanup test @ruslandoga (#938)

## 1.17.3

### ✨ Features

- feat(mailjet): add event\_payload to provider options @mrdotb (#965)
- Handle direct URL specification on MSGraph.deliver @LetThereBeDwight (#967)
- Complete Swoosh.X.TestAssertions @edgarlatorre (#924)
- Add CSS labels to email detail elements @alexslade (#956)

## 1.17.2

### ✨ Features

- fix: download attachment with the filename @RETFU (#957)

## 1.17.1

### 🐛 Bug Fixes

- Update the MSGraph Adapter Dependency @LetThereBeDwight (#955)

## 1.17.0

A new adapter for Postal, thanks to @onvlt

### ✨ Features

- Implement Postal adapter @onvlt (#949)

## 1.16.12

### ✨ Features

- Add toggle for text preview @andreicek (#947)

## 1.16.11

### ✨ Features

- mua: add Date and Message-ID headers when missing @ruslandoga (#945)

### 📝 Documentation

- Write docs for functions in Mailer \_\_using\_\_ macro  @ivanhercaz (#946)
- Explain how to recompile after installing gen\_smtp @aj-foster (#944)
- Fix typos and improve language @preciz (#943)

## 1.16.10

### 🐛 Bug Fixes

- mua: no mx when relay @ruslandoga (#934)

### 📝 Documentation

- mua: update docs @ruslandoga (#935)

## 1.16.9

### 🐛 Bug Fixes

- Fix ex\_aws region override @hellomika (#914)

## 1.16.8

### Breaking Change

`Mua` is bumped to `0.2.0`, and brings some breaking changes. The [change](https://github.com/ruslandoga/mua/pull/44) in v0.2.0 is splitting `transport_opts` into `tcp` and `ssl` specific ones since `:gen_tcp.connect` complains when it receives opts for `:ssl.connect`.

### 🧰 Maintenance

- update mua to v0.2.0 @ruslandoga (#911)

## 1.16.7

### ✨ Features

- Add support for tracking and return path domains for Mandrill @cenavarro (#906)

## 1.16.6

### ✨ Features

- add Swoosh.Adapters.ZeptoMail @gBillal (#905)

### 📝 Documentation

- Fix typo in docs @pguillory (#898)

## 1.16.5

### ✨ Features

- Add config options for AmazonSES adapter @otlaitil (#897)

## 1.16.4

### ✨ Features

- Add support for allow\_nil\_from @bernardd (#895)

### 🧰 Maintenance

- remove unstable assertion @princemaple (#892)

## 1.16.3

### ✨ Features

- Mailbox Preview: more space for the HTML preview @justincy (#882)

### 🐛 Bug Fixes

- Fix Mailgun adapter incompatibility with Finch @AndrewDryga (#883)

## 1.16.2

### 🐛 Bug Fixes

- Update `MixProject` `xref` exclusions [`MultiPart.Part`] @jbcaprell (#880)

## 1.16.1

With #877 Mailgun adapter now supports API Clients other than Hackney. Mailgun users,
please add [`:multipart`](https://hex.pm/packages/multipart) to your dependency list.

## 🐛 Bug Fixes

- Rewrite multipart functionality to use a encoding builder @krainboltgreene (#877)
- Fix Req header handling @wojtekmach (#879)

## 1.16.0

### ✨ Features

Thank you @ruslandoga very much for throwing in this gem.

- Add Swoosh.Adapters.Mua, an alternative SMTP adapter @ruslandoga (#870)

## 1.15.3

### ✨ Features

- [SMTP2GO] Pass more info down from the API response

## 1.15.2

### ✨ Features

- Add support of subaccount and tags for Mandrill @cenavarro (#860)

### 📝 Documentation

- Clarify Postmark docs about template model @TheArrowsmith (#859)

## 1.15.1

### ✨ Features

- Add support for Bandit @mtrudel (#857)

## 1.15.0

### ✨ Features

- Support multiple reply\_to in sendgrid @princemaple (#853)
- Support reply\_to in smtp2go @princemaple (#852)
- Feat mailgun multiple reply to @ghostdsb (#850)

### 📝 Documentation

- Improve docs on adapter functions and deliver_many in general

## 1.14.4

### ✨ Features

- AmazonSES: add :ses\_source option to set Source API parameter @adamu (#846)

### 📝 Documentation

- fix comma issues on adapter config samples @SirWerto (#842)

## 1.14.3

### ✨ Features

- Add template options @princemaple (#839)

### 📝 Documentation

- mention proton smtp, close #837 @princemaple (#840)

## 1.14.2

### ✨ Features

- Do not send subject to customer.io when empty @caioaao (#834)

### 📝 Documentation

- Add information about Mailtrap adapter in README.md @kalys (#833)
- Add req docs to Api Client section @krns (#831)

## 1.14.1

### ✨ Features

- Add Swoosh.ApiClient.Req @matthewlehner (#830)

## 1.14.0

### ✨ Features

- Implement Mailtrap adapter @kalys (#827)

### 📝 Documentation

- Add a note about the Tailwindcss cdn when using a CSP @Hermanverschooten (#828)

## 1.13.0

### ✨ Features

- Add Scaleway adapter @andreh11 (#825)
- Update the UI for the mailbox viewer @dsincl12 (#822)

## 1.12.0

### ✨ Features

- Implement Swoosh.Adapters.MsGraph @justindotpub (#815)

### 📝 Documentation

- Update return value in docs @princemaple (#813)

## 1.11.6

### 🐛 Bug Fixes

- Add `plug` as an explicit dependency though still optional

## 1.11.5

### 🧰 Maintenance

- Deprecate system env tuples @josevalim (#800)
- Use concatenation to build sup children @josevalim (#801)
- Compute docs lazily @josevalim (#802)

## 1.11.4

### 🐛 Bug Fixes

- Race condition on @on_load callback (#792) (quick fix in aef9cccbd)

### 📝 Documentation

- Update Mailgun docs for sandbox mode @stjhimy (#787)


## 1.11.3

### 📝 Documentation

- Fix sections on CHANGELOG @nelsonmestevao (#781)

### 🧰 Maintenance

- SendInBlue -> Brevo @princemaple (#783)


## 1.11.2

### 🐛 Bug Fixes

- Fix BCC for adapters that depend on SMTP helper @princemaple (#779)

### 📝 Documentation

- Remove unnecessary sentence from README @adamu (#776)

## 1.11.1

### 🐛 Bug Fixes

- Do not include Bcc header in delivered email @adamu (#773) Thanks heaps for the discussion and PR!

### 🧰 Maintenance

- Bump mime from 2.0.3 to 2.0.5 @dependabot (#771)

## 1.11.0

### ✨ Features

- Add experimental new test assertion module @jakub-gonet (#747)

## 1.10.3

### 🐛 Bug Fixes

#### SMTP

- Fix inline attachment showing up twice as both inline and attachment @Hermanverschooten (#769)


## 1.10.2

### 🐛 Bug Fixes

- Corrects typo in ex\_aws\_amazon\_ses.ex @paynegreen (#766)

## 1.10.1

### ✨ Features

- Allow Regexp assertions for subjects @aronisstav (#764)

### 🧰 Maintenance

- Bump finch from 0.15.0 to 0.16.0 @dependabot (#762)

## 1.10.0

### ✨ Features

- Add assert\_emails\_sent @geeksilva97 (#757)
- Add postmark inline\_css option @matehat (#759)

### 📝 Documentation

- Make Adapters.ExAwsAmazonSES easier to discover @nathanl (#749)
- Add notes about API Client @Shadowbeetle (#743)

### 🧰 Maintenance

- Move docs above maintenance @princemaple (#760)

## 1.9.1

### ✨ Features

- Add support for Protonmail Bridge @Raphexion (#739)

### 📝 Documentation

- Fix more typos @kianmeng (#736)

## 1.9.0

### ✨ New Adapter

- Add customer.io adapter @lucacorti (#734) 

## 1.8.3

**potential breaking change, fixing an unexpected behaviour**
- Make return type of deliver\_many consistent @princemaple (#733)

### 📝 Documentation
- Fix typo in contributor guidelines @nickcampbell18 (#727)

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

### 📝 Documentation

- doc: correct tags example for Adapters.Sendinblue @03juan (#711)

## 1.7.4

### ✨ Features

- Set attachment's ContentId in Mailjet @marcinkoziej (#709)

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

### 📝 Documentation

- fix module name in ExAwsAmazonSES module doc @SteffenDE (#689)

## 1.6.6

- Suppress warning about `ExAws.Config` introduced in 1.6.5 as optional dependency

## 1.6.5

- Add `Swoosh.Adapters.ExAwsAmazonSES` adapter @ascandella (#684)

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
