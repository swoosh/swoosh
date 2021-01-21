[
  import_deps: [:plug],
  inputs: ["*.{ex,exs}", "priv/*/seeds.exs", "{config,lib,test}/**/*.{ex,exs}"],
  export: [
    locals_without_parens: [
      assert_email_not_sent: 1,
      assert_email_sent: 0,
      assert_email_sent: 1,
      assert_no_email_sent: 0,
      refute_email_sent: 0,
      refute_email_sent: 1
    ]
  ]
]
