defmodule Swoosh.Mixfile do
  use Mix.Project

  @source_url "https://github.com/swoosh/swoosh"
  @version "1.19.5"

  def project do
    [
      app: :swoosh,
      version: @version,
      elixir: "~> 1.13",
      elixirc_paths: elixirc_paths(Mix.env()),
      consolidate_protocols: Mix.env() != :test,
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps(),

      # Hex
      description: description(),
      package: package(),

      # Docs
      name: "Swoosh",
      source_url: @source_url,
      homepage_url: @source_url,
      docs: &docs/0,
      preferred_cli_env: [
        docs: :docs,
        "hex.publish": :docs
      ],

      # Suppress warnings
      xref: [
        exclude: [
          :hackney,
          :gen_smtp_client,
          :mimemail,
          ExAws.Config,
          Finch,
          Req,
          Plug.Adapters.Cowboy,
          Plug.Conn.Query,
          Plug.Cowboy,
          Bandit,
          Mail,
          Mail.Message,
          Mail.Renderers.RFC2822,
          Mua,
          Multipart,
          Multipart.Part,
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
      {:mime, "~> 1.1 or ~> 2.0"},
      {:jason, "~> 1.0"},
      {:telemetry, "~> 0.4.2 or ~> 1.0"},
      {:hackney, "~> 1.9", optional: true},
      {:finch, "~> 0.6", optional: true},
      {:req, "~> 0.5.10 or ~> 0.6 or ~> 1.0", optional: true},
      {:mail, "~> 0.2", optional: true},
      {:gen_smtp, "~> 0.13 or ~> 1.0", optional: true},
      {:mua, "~> 0.2.3", optional: true},
      {:cowboy, "~> 1.1 or ~> 2.4", optional: true},
      {:plug, "~> 1.9", optional: true},
      {:plug_cowboy, ">= 1.0.0", optional: true},
      {:bandit, ">= 1.0.0", optional: true},
      {:multipart, "~> 0.4", optional: true},
      {:ex_aws, "~> 2.1", optional: true},
      {:bypass, "~> 2.1", only: :test},
      {:ex_doc, "~> 0.26", only: :docs, runtime: false},
      {:tailwind, "~> 0.3.1", only: [:docs, :dev], runtime: false}
    ]
  end

  @deprecated_adapters [
    Swoosh.Adapters.OhMySmtp,
    Swoosh.Adapters.Sendinblue
  ]

  defp docs do
    [
      source_ref: "v#{@version}",
      main: "Swoosh",
      canonical: "http://hexdocs.pm/swoosh",
      source_url: @source_url,
      extras: [
        "CHANGELOG.md",
        "CODE_OF_CONDUCT.md",
        "CONTRIBUTING.md"
      ],
      groups_for_modules: [
        Email: [
          Swoosh.Email,
          Swoosh.Email.Recipient
        ],
        Adapters: adapter_modules(),
        "Api Client": [
          Swoosh.ApiClient,
          Swoosh.ApiClient.Finch,
          Swoosh.ApiClient.Hackney,
          Swoosh.ApiClient.Req
        ],
        Plug: Plug.Swoosh.MailboxPreview,
        Test: [
          Swoosh.TestAssertions,
          Swoosh.X.TestAssertions
        ],
        Deprecated: @deprecated_adapters
      ]
    ]
  end

  defp adapter_modules do
    Path.wildcard("lib/swoosh/adapters/*.ex")
    |> Enum.map(fn path ->
      content = File.read!(path)
      [_, module] = Regex.run(~r/\Adefmodule (.+) do/, content)
      module |> String.split(".") |> Module.concat()
    end)
    |> Kernel.--(@deprecated_adapters)
  end

  defp description do
    """
    Compose, deliver and test your emails easily in Elixir. Supports SMTP,
    Sendgrid, Mandrill, Postmark, Mailgun and many more out of the box.
    Preview your emails in the browser. Test your email sending code.
    """
  end

  defp package do
    [
      maintainers: ["Steve Domin", "Baris Balic", "Po Chen"],
      licenses: ["MIT"],
      links: %{
        "Changelog" => "#{@source_url}/blob/main/CHANGELOG.md",
        "GitHub" => @source_url
      }
    ]
  end
end
