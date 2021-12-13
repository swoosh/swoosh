import Config

if Mix.env() == :test do
  config :logger, level: :info
  config :bypass, adapter: Plug.Adapters.Cowboy2
end
