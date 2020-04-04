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
    cond do
      (with text when text |> is_binary() <- message["text"] do
        unless try_handle_request text, from do
          case Repo.insert(%Message{from: from, message: text}) do
            {:ok, _} -> IO.puts "Successfully saved message to the Database"
            something_else -> IO.puts "Oops, something went not quite as expected\n#{inspect something_else}"
          end
        end
        true
      end) -> true
      (with %{} = voice <- message["voice"] do
        Nadia.send_message from, "Слушаю ваше сообщение"
        # Nadia.send_message from, "I see you sent a voice message to me, I'll try to download it first"
        file_id = voice["file_id"]
        case Nadia.get_file(file_id) do
          {:ok, %Nadia.Model.File{file_path: file_path}} ->
            Nadia.send_message from, "I've got the file path [#{file_path}]"
            BotState.set_last_file_path file_path
            parse_voice_message file_path, from
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
      try_get_last_file_path(text, from) -> true
      try_get_last_file_size(text, from) -> true
      try_send_speech_to_text_request(text, from) -> true
      try_send_last_file_uri(text, from) -> true
      try_get_author(text, from) -> true
      true -> false
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

  defp try_get_last_file_size(text, from) do
    if text && text =~ ~r/get\s+last\s+file\s+size/i do
      last_file_path = BotState.get_last_file_path
      if last_file_path do
        Nadia.send_message from, "I see I have file [#{last_file_path}]. I'll try to go and download it."
        token = System.get_env("BOT_TOKEN")
        IO.puts "Going to send reqest to try and download file"
        case HTTPoison.get(~s|https://api.telegram.org/file/bot#{token}/#{last_file_path}|) do
          {:ok, %HTTPoison.Response{status_code: status_code, body: body}} ->
            if status_code >= 200 and status_code < 299 do
              Nadia.send_message from, "Received good response of length #{byte_size(body)} bytes"
            else
              Nadia.send_message from, "Received status code: #{status_code}"
            end
          {:error, %HTTPoison.Error{reason: reason}} ->
            Nadia.send_message from, "Returned bad response with reason: #{inspect reason}"
        end
        IO.puts "After the HTTP request being executed"
      else
        Nadia.send_message from, "Last file name is not set in the bot state"
      end
      true
    end
  end

  defp parse_voice_message(voice_file_path, from) do
    token = System.get_env("BOT_TOKEN")
    IO.puts "Going to send reqest to try and download file"
    case HTTPoison.get(~s|https://api.telegram.org/file/bot#{token}/#{voice_file_path}|) do
      {:ok, %HTTPoison.Response{status_code: status_code, body: body}} ->
        if status_code >= 200 and status_code < 299 do
          IO.puts "Received good response of length #{byte_size(body)} bytes"
          message =
            case voice_to_text body, from do
              {:transrcipt, transcript} ->
                transcript
              _ -> "Не получилось распознать голос"
            end
          Nadia.send_message from, message
        else
          Nadia.send_message from, "Received status code: #{status_code}"
        end
      {:error, %HTTPoison.Error{reason: reason}} ->
        Nadia.send_message from, "Returned bad response with reason: #{inspect reason}"
    end
  end

  defp voice_to_text(file_contents, from) do
    base64body = Base.encode64(file_contents)
    g_api_key = System.get_env("G_API_KEY")
    case HTTPoison.post(
      "https://speech.googleapis.com/v1/speech:recognize?key=#{g_api_key}",
      ~s"""
      {
        "config": {
          "encoding": "OGG_OPUS",
          "sampleRateHertz": 48000,
          "languageCode": "ru-RU"
        },
        "audio": {
          "content": "#{base64body}"
        }
      }
      """,
      [{"Content-Type", "application/json"}],
      []) do
        {:ok, %HTTPoison.Response{status_code: speech_status_code, body: speech_body}} ->
          if speech_status_code >= 200 and speech_status_code <= 299 do
            IO.puts "Received good response from speech recognition API"
            IO.puts "#{inspect speech_body}"
            result_map = Jason.decode! speech_body
            transcript = get_best_result result_map
            # with %{"alternatives" => alternatives} <- result_map["results"] |> Enum.at(0), alternative <- alternatives |> Enum.at(0), transcript <- alternative["transcript"] do
            #   Nadia.send_message from, transcript
            # end
            {:transcript, transcript}
          else
            Nadia.send_message from, "Received bad response with status code: #{speech_status_code}, body: #{speech_body}"
          end
        {:error, %HTTPoison.Error{reason: speech_failure_reason}} ->
          Nadia.send_message from, "Failed speech recognition request for reason: #{inspect speech_failure_reason}"
      end
  end

  defp get_best_result(results) do
    with %{transcript: best_transcript, confidence: _confidence} <- results |> Enum.reduce(nil, fn result, best ->
      with %{"alternatives" => alternatives} <- result do
        alternatives |> Enum.reduce(best, fn alternative, value ->
          with %{"transcript" => transcript, "confidence" => confidence} <- alternative do
            if value === nil or confidence > value.confidence, do: %{confidence: confidence, transcript: transcript}, else: value
          else
            _ -> value
          end
        end)
      else
        _ -> best
      end
    end) do
      best_transcript
    else
      _ -> "Oops"
    end
  end

  defp try_get_author(text, from) do
    if text && text =~ ~r/твой\s+(автор|создатель)/i do
      get_author from
      true
    end
  end

  defp get_author(from) do
    Nadia.send_message from, "Мой создатель - Дмитрий Пятков"
  end

  defp try_send_last_file_uri(text, from) do
    if text && text =~ ~r/send\s+last\s+file\sur[il]/i do
      send_last_file_uri from
      true
    end
  end

  defp send_last_file_uri(from) do
    message =
      case BotState.get_last_file_path do
        last_file_path when last_file_path |> is_binary() and byte_size(last_file_path) > 0 ->
          token = System.get_env("BOT_TOKEN")
          ~s|https://api.telegram.org/file/bot#{token}/#{last_file_path}|
        _ -> "Last file name is not set in the bit state"
      end
    Nadia.send_message from, message
  end

  defp try_send_speech_to_text_request(text, from) do
    if text && text =~ ~r/gecognize\s+speech/i do
      last_file_path = BotState.get_last_file_path
      if last_file_path do
        Nadia.send_message from, "I see there is a file [#{last_file_path}]. I'll try tp go and submit a request to speech to text service."
        token = System.get_env("BOT_TOKEN")
        case HTTPoison.get(~s|https://api.telegram.org/file/bot#{token}/#{last_file_path}|) do
          {:ok, %HTTPoison.Response{status_code: status_code, body: body}} ->
            if status_code >= 200 and status_code < 299 do
              Nadia.send_message from, "Received good response of length #{byte_size(body)} bytes"
              base64body = Base.encode64(body)
              g_api_key = System.get_env("G_API_KEY")
              case HTTPoison.post(
                "https://speech.googleapis.com/v1/speech:recognize?key=#{g_api_key}",
                ~s"""
                {
                  "config": {
                    "encoding": "OGG_OPUS",
                    "sampleRateHertz": 48000,
                    "languageCode": "ru-RU"
                  },
                  "audio": {
                    "content": "#{base64body}"
                  }
                }
                """,
                [{"Content-Type", "application/json"}],
                []) do
                  {:ok, %HTTPoison.Response{status_code: speech_status_code, body: speech_body}} ->
                    if speech_status_code >= 200 and speech_status_code <= 299 do
                      Nadia.send_message from, "Received good response from speech recognition API"
                      Nadia.send_message from, "#{inspect speech_body}"
                    else
                      Nadia.send_message from, "Received bad response with status code: #{speech_status_code}, body: #{speech_body}"
                    end
                  {:error, %HTTPoison.Error{reason: speech_failure_reason}} ->
                    Nadia.send_message from, "Failed speech recognition request for reason: #{inspect speech_failure_reason}"
                end
            else
              Nadia.send_message from, "Received status code: #{status_code}"
            end
          {:error, %HTTPoison.Error{reason: reason}} ->
            Nadia.send_message from, "Returned bad response with reason: #{inspect reason}"
        end
      else
        Nadia.send_message from, "Last gile name is not set in the bot state"
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
