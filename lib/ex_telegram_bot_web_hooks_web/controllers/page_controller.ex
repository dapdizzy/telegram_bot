defmodule ExTelegramBotWebHooksWeb.PageController do
  use ExTelegramBotWebHooksWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
