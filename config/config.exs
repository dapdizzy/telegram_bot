# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

config :ex_telegram_bot_web_hooks,
  ecto_repos: [ExTelegramBotWebHooks.Repo]

# Configures the endpoint
config :ex_telegram_bot_web_hooks, ExTelegramBotWebHooksWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "Pqpv+G2gSizStoZ79sXoedwO4r+1Onx2IuxnDzyWW517zIqRw5kR5KAmu9B0vdeh",
  render_errors: [view: ExTelegramBotWebHooksWeb.ErrorView, accepts: ~w(html json)],
  pubsub: [name: ExTelegramBotWebHooks.PubSub, adapter: Phoenix.PubSub.PG2],
  live_view: [signing_salt: "m2QPIBHu"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
