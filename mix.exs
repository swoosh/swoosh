defmodule Swoosh.Mixfile do
  use Mix.Project

  @version "0.13.0"

  def project do
    [
      app: :swoosh,
      version: @version,
      elixir: "~> 1.4",
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
        exclude: [:gen_smtp_client, :mimemail, Plug.Adapters.Cowboy, Plug.Conn.Query]
      ]
    ]
  end

  def application do
    [applications: [:logger, :hackney, :mime], mod: {Swoosh.Application, []}]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:hackney, "~> 1.9"},
      {:mime, "~> 1.1"},
      {:jason, "~> 1.0"},
      {:gen_smtp, "~> 0.12", optional: true},
      {:cowboy, "~> 1.0", optional: true},
      {:plug, "~> 1.4", optional: true},
      {:credo, "~> 0.8", only: [:dev, :test]},
      {:bypass, "~> 0.8", only: :test},
      {:ex_doc, "~> 0.16", only: :docs, runtime: false},
      {:inch_ex, ">= 0.0.0", only: :docs}
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
