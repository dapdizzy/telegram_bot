defmodule ExTelegramBotWebHooksWeb.WebHooksController do
  alias ExTelegramBotWebHooks.Message
  alias ExTelegramBotWebHooks.Repo
  alias ExTelegramBotWebHooks.BotState
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
    cond do
      (with text <- message["text"], text != nil do
        unless try_handle_request text, from do
          case Repo.insert(%Message{from: from, message: text}) do
            {:ok, _} -> IO.puts "Successfully saved message to the Database"
            something_else -> IO.puts "Oops, something went not quite as expected\n#{inspect something_else}"
          end
        end
        true
      end) -> true
      (with voice <- message["voice"], voice != nil do
        Nadia.send_message from, "I see you sent a voice message to me, I'll try to download it first"
        file_id = voice["file_id"]
        case Nadia.get_file(file_id) do
          {:ok, %Nadia.Model.File{file_path: file_path}} ->
            Nadia.send_message from, "I've got the file path [#{file_path}]"
            BotState.set_last_file_path file_path
          {:error, error} ->
            Nadia.send_message from, "Got error: #{inspect error}"
        end
      end) -> true
    end
    # unless try_handle_request text, from do
    #   case Repo.insert(%Message{from: from, message: text}) do
    #     {:ok, _} -> IO.puts "Successfully saved message to the Database"
    #     something_else -> IO.puts "Oops, something went not quite as expected\n#{inspect something_else}"
    #   end
    # end
    json conn, params
  end

  defp try_handle_request(text, from) do
    cond do
      try_get_my_messages(text, from) -> true
    end
  end

  defp try_get_my_messages(text, from) do
    if text && text =~ ~r/my\s+messages/i do
      message = "Sending your messages"
      Nadia.send_message(from, message)
      your_messages = Message |> Ecto.Query.where([m], from: ^from) |> Repo.all
        |> Stream.map(fn %Message{message: msg} -> msg end)
        |> Enum.join("\n")
      Nadia.send_message(from, your_messages)
      true
    end
  end

  defp try_get_last_file_path(text, from) do
    if text && text =~ ~r/show\s+last\s+file/i do
      last_file_path = BotState.get_last_file_path
      if last_file_path do
        Nadia.send_message from, "last file name is: [#{last_file_path}]"
      else
        Nadia.send_message from, "Last file name is not set in the bot state"
      end
      true
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
