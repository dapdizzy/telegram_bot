defmodule ExTelegramBotWebHooks.Repo do
  use Ecto.Repo,
    otp_app: :ex_telegram_bot_web_hooks,
    adapter: Ecto.Adapters.Postgres
end
