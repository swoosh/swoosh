import Config

if Mix.env() == :test do
  config :logger, level: :info
  config :bypass, adapter: Plug.Adapters.Cowboy2
end

if Mix.env() in [:dev, :docs] do
  config :tailwind,
    version: "4.2.1",
    default: [
      args: ~w(
        --input=lib/plug/assets/app.css
        --output=priv/static/assets/app.css
      ),
      cd: Path.expand("..", __DIR__)
    ]
end
