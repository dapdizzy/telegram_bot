defmodule ExTelegramBotWebHooksWeb.WebHooksController do
  use ExTelegramBotWebHooksWeb, :controller

  def receive_messages(conn, params) do
    json_params = json conn, params
    IO.puts "Json params arrived:\n#{json_params}"
    queue_name = Application.get_env(:ex_telegram_bot_web_hooks, :messages_queue)
    RabbitMQSender |> RabbitMQSender.send_message(queue_name, json_params)
    json_params
  end

  def set_webhook(conn, params) do
    reply =
      case params["callback_url"] do
        url when url |> is_binary() and byte_size(url) > 0 ->
          case Nadia.set_webhook(url: url) do
            :ok -> "Set Webhook callback to [#{url}]"
            {:error, error} -> "An error occured\n#{inspect error}"
          end
        _ -> ~S|No callback URL was provided in the "callback_url" key|
      end
    text conn, reply
  end

  def get_me(conn, _params) do
    me = Nadia.get_me
    text conn, "#{inspect me}"
  end

end
