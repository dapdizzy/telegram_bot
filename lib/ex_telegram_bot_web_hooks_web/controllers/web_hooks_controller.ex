defmodule ExTelegramBotWebHooksWeb.WebHooksController do
  alias ExTelegramBotWebHooks.Message
  alias ExTelegramBotWebHooks.Repo
  require Ecto.Query
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
    unless try_handle_request text, from do
      case Repo.insert(%Message{from: from, message: text}) do
        {:ok, _} -> IO.puts "Successfully saved message to the Database"
        something_else -> IO.puts "Oops, something went not quite as expected\n#{inspect something_else}"
      end
    end
    json conn, params
  end

  defp try_handle_request(text, from) do
    if text && text =~ ~r/my\s+messages/i do
      message = "Sending your messages"
      Nadia.send_message(from, message)
      your_messages = Message |> Ecto.Query.where([m], from: ^from) |> Repo.all
        |> Stream.map(fn %Message{message: msg} -> msg end)
        |> Enum.join("\n")
      Nadia.send_message(from, your_messages)
      :ok
    end
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
