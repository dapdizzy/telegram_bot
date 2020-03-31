defmodule ExTelegramBotWebHooks.BotState do
  defstruct [:last_file_path]
  use Agent

  def start_link(initial_state \\ nil) do
    Agent.start_link(fn -> initial_state || %__MODULE__{} end, name: __MODULE__)
  end

  def get_last_file_path, do: __MODULE__ |> Agent.get(fn %__MODULE__{last_file_path: last_file_path} -> last_file_path end)
  def set_last_file_path(last_file_path), do: __MODULE__ |> Agent.update(fn state -> %{state|last_file_path: last_file_path} end)
end
