defmodule ExTelegramBotWebHooks.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    rabbitMQConnectionOptions =
      [
        host: System.get_env("RABBITMQ_HOST"),
        username: System.get_env("RABBITMQ_USERNAME"),
        virtual_host: System.get_env("RABBITMQ_VIRTUAL_HOST"),
        password: System.get_env("RABBITMQ_PASSWORD")
      ]

    # List all child processes to be supervised
    children = [
      # Start the endpoint when the application starts
      ExTelegramBotWebHooksWeb.Endpoint,
      # Starts a worker by calling: ExTelegramBotWebHooks.Worker.start_link(arg)
      # {ExTelegramBotWebHooks.Worker, arg},
      worker(
        RabbitMQSender,
        [rabbitMQConnectionOptions, [name: RabbitMQSender], [exchange: "bot_messages_exchange_topic", exchange_type: :topic]]
        )
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ExTelegramBotWebHooks.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    ExTelegramBotWebHooksWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
