# Contributing to Swoosh

Thanks for thinking about contributing to Swoosh. Please review this document
first and also take a look at our [Code of Conduct](CODE_OF_CONDUCT.md), to
help us keep this project inclusive to all those that may wish to contribute
also.

## Opening Issues

We classify bugs as any unexpected behaviour that occurs based on the code in
the project, and we really appreciate it when users take the time to
[create an issue](https://github.com/swoosh/swoosh/issues).

Please take time to add as much detail as you can to any bug reports, consider
including things like the version of Elixir you are using, which adapter you
are having trouble with and any custom config you have passed for that adapter.

If you are thinking about adding a feature, you should the check Issues first,
someone else may have started already, or it might be a feature we've decided
not to implement intentionally.

## Submitting Pull Requests

Whether you're fixing a bug, or proposing a feature you'd like to see included,
you can submit Pull Requests by following this guide:

1. [Fork this repository](https://github.com/swoosh/swoosh/fork) and then clone
   it locally:

  ```bash
  git clone https://github.com/swoosh/swoosh
  ```

2. Create a topic branch for your changes:

  ```bash
  git checkout -b fix-mailchimp-pricing-bug
  ```

3. Commit a failing test for the bug:

  ```bash
  git commit -am "Adds a failing test that demonstrates the bug"
  ```

4. Commit a fix that makes the test pass:

  ```bash
  git commit -am "Adds a fix for the bug"
  ```

5. Run the tests:

  ```bash
  mix test
  ```

6. If everything looks good, push to your fork:

  ```bash
  git push origin fix-mailchimp-pricing-bug
  ```

7. [Submit a pull request.](https://help.github.com/articles/creating-a-pull-request)

## Style guidelines

We support the common conventions found in Elixir, if you're in doubt take a
look at the code in the project, and we would like to keep the style consistent
throughout.

### General rules

- Keep line length below 120 characters.
- Complex anonymous functions should be extracted into named functions.
- One line functions, should only take up one line!
- Pipes are great, but don't use them, if they are less readable than brackets
  then drop the pipe!
