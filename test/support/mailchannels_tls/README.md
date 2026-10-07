# MailChannels local TLS tests

Run `test/support/mailchannels_tls/run.sh` from a checkout with Docker available.
These tests are manual: CI does not run them, so run them after changing the
adapter's transport, request mapping or response handling.
The first container fetches dependencies; the second has `--network none` and maps
both test hostnames to loopback. It runs only the MailChannels TLS tests, with
synthetic credentials. No live MailChannels API access is required or performed.
The runner writes dependency/build artifacts to the checkout and caches Hex/Mix
under the user's cache directory; SWOOSH_MAILCHANNELS_CACHE can override it.

Certificates/private keys are generated inside the ephemeral test container. Its
Erlang trust store trusts only the fixture CA for these tests. The adapter retains
the production endpoint, allowing the tests to verify peer/hostname checks and
request destination without a configurable base URL.

The tests are skipped unless MAILCHANNELS_LOCAL_TLS_FIXTURE=1; they additionally
require api.mailchannels.net to resolve to 127.0.0.1. Do not enable the variable in
a normal development or provider integration environment. Ordinary `mix test` and
other integration tests do not enable the fixture.

Cases cover 202 acceptance, wrong-host/untrusted-CA failure before HTTP data,
redirects and error statuses without replay, disconnect/truncated response/receive
timeout, proxy environment variables and disabled response decompression. These
are client behavior tests, not validation of provider delivery or job idempotency.
