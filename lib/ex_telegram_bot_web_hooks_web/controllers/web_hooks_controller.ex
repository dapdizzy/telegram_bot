defmodule ExTelegramBotWebHooksWeb.WebHooksController do
  alias ExTelegramBotWebHooks.Message
  use ExTelegramBotWebHooksWeb, :controller

  def receive_messages(conn, params) do
    params_as_text = IO.inspect(params)
    IO.puts "Json params arrived:\n#{inspect params_as_text}"
    queue_name = Application.get_env(:ex_telegram_bot_web_hooks, :messages_queue)
    IO.puts "Sending a message to #{queue_name}"
    RabbitMQSender |> RabbitMQSender.send_message(queue_name, Jason.encode!(params))
    message = params["message"]
    from = message["from"]["id"]
    text = message["text"]
    case Repo.insert(%Message{from: from, message: text}) do
      {:ok, _} -> IO.puts "Successfully saved message to the Database"
      something_else -> IO.puts "Oops, something went not quite as expected\n#{inspect something_else}"
    end
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
