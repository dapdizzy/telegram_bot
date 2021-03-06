defmodule ExTelegramBotWebHooksWeb.Router do
  use ExTelegramBotWebHooksWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", ExTelegramBotWebHooksWeb do
    pipe_through :browser

    get "/", PageController, :index
  end

  # Other scopes may use custom stacks.
  scope "/api", ExTelegramBotWebHooksWeb do
    pipe_through :api

    post "/web_hook", WebHooksController, :receive_messages
    post "/wet_webhook", WebHooksController, :set_webhook
    get "/get_me", WebHooksController, :get_me
  end
end
