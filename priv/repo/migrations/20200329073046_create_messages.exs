defmodule ExTelegramBotWebHooks.Repo.Migrations.CreateMessages do
  use Ecto.Migration

  def change do
    create table(:messages) do
      add :from, :integer
      add :message, :string

      timestamps()
    end

  end
end
