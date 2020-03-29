defmodule ExTelegramBotWebHooks.Message do
  use Ecto.Schema
  import Ecto.Changeset

  schema "messages" do
    field :from, :integer
    field :message, :string

    timestamps()
  end

  @doc false
  def changeset(message, attrs) do
    message
    |> cast(attrs, [:from, :message])
    |> validate_required([:from, :message])
  end
end
