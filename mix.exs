defmodule Swoosh.Mixfile do
  use Mix.Project

  @version "1.0.1"

  def project do
    [
      app: :swoosh,
      version: @version,
      elixir: "~> 1.8",
      elixirc_paths: elixirc_paths(Mix.env()),
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),

      # Hex
      description: description(),
      package: package(),

      # Docs
      name: "Swoosh",
      source_url: "https://github.com/swoosh/swoosh",
      homepage_url: "https://github.com/swoosh/swoosh",
      docs: [
        source_ref: "v#{@version}",
        main: "Swoosh",
        canonical: "http://hexdocs.pm/swoosh",
        source_url: "https://github.com/swoosh/swoosh"
      ],

      # Suppress warnings
      xref: [
        exclude: [
          :hackney,
          :gen_smtp_client,
          :mimemail,
          Plug.Adapters.Cowboy,
          Plug.Conn.Query,
          Plug.Cowboy,
          Mail,
          Mail.Renderers.RFC2822,
          {IEx, :started?, 0}
        ]
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger, :xmerl],
      mod: {Swoosh.Application, []},
      env: [json_library: Jason, api_client: Swoosh.ApiClient.Hackney]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:mime, "~> 1.1"},
      {:jason, "~> 1.0"},
      {:hackney, "~> 1.9", optional: true},
      {:gen_smtp, "~> 0.13", optional: true},
      {:cowboy, "~> 1.0.1 or ~> 1.1 or ~> 2.4", optional: true},
      {:plug_cowboy, ">= 1.0.0", optional: true},
      {:bypass, "~> 1.0", only: :test},
      {:ex_doc, "~> 0.16", only: :docs, runtime: false},
      {:inch_ex, ">= 0.0.0", only: :docs},
      {:mail, "~> 0.2", optional: true}
    ]
  end

  defp aliases do
    ["test.ci": &test_ci/1]
  end

  defp test_ci(args) do
    args = if IO.ANSI.enabled?(), do: ["--color" | args], else: ["--no-color" | args]

    args =
      if System.get_env("TRAVIS_SECURE_ENV_VARS") == "true",
        do: ["--include=integration" | args],
        else: args

    {_, res} =
      System.cmd(
        "mix",
        ["test" | args],
        into: IO.binstream(:stdio, :line),
        env: [{"MIX_ENV", "test"}]
      )

    if res > 0 do
      System.at_exit(fn _ -> exit({:shutdown, 1}) end)
    end
  end

  defp description do
    """
    Compose, deliver and test your emails easily in Elixir. Supports SMTP, Sendgrid, Mandrill, Postmark and Mailgun out of the box.
    Preview your mails in the browser. Great integration with Phoenix.
    """
  end

  defp package do
    [
      maintainers: ["Steve Domin", "Baris Balic", "Po Chen"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/swoosh/swoosh"}
    ]
  end
end
