defmodule ExTelegramBotWebHooksWeb.WebHooksController do
  use ExTelegramBotWebHooksWeb, :controller

  def receive_messages(conn, params) do
    params_as_text = inspect(params)
    IO.puts "#{inspect params_as_text}"
    text conn, params_as_text
  end

  def set_webhook(conn, params) do
    reply =
      case params["callback_url`"] do
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
