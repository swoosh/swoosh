use Mix.Config

config :bypass, adapter: Plug.Adapters.Cowboy2

if Mix.env() == :test do
  config :logger, level: :info
end
