defmodule ExTelegramBotWebHooksWeb.WebHooksController do
  use ExTelegramBotWebHooksWeb, :controller

  def receive_messages(conn, params) do
    params_as_text = inspect(params)
    IO.puts "#{inspect params_as_text}"
    text conn, params_as_text
  end

end
