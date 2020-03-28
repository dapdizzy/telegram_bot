defmodule ExTelegramBotWebHooksWeb.WebHooksController do
  use ExTelegramBotWebHooksWeb, :controller

  def receive_messages(conn, params) do
    params_as_text = IO.inspect(params)
    IO.puts "Json params arrived:\n#{inspect params_as_text}"
    queue_name = Application.get_env(:ex_telegram_bot_web_hooks, :messages_queue)
    IO.puts "Sending a message to #{queue_name}"
    RabbitMQSender |> RabbitMQSender.send_message(queue_name, params)
    json conn, params
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
