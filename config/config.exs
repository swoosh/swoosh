use Mix.Config

config :swoosh, :json_library, Jason

config :bypass, adapter: Plug.Adapters.Cowboy2
