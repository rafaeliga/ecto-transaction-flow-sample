Mix.install([
  :jason,
  :ecto_sql,
  :postgrex,
  :flow
])

defmodule Scenario.Repo do
  use Ecto.Repo, otp_app: :scenario, adapter: Ecto.Adapters.Postgres
end

defmodule Scenario.SetupMigration do
  use Ecto.Migration

  def up do
    create table(:products) do
      add(:name, :string)

      timestamps()
    end
    
    create(unique_index(:products, [:name]))
    
    create table(:configs) do
      add(:lines, :string)

      timestamps()
    end
  end

  def down do
    drop(table("products"))
    drop(table("configs"))
  end
end

Application.put_env(:scenario, Scenario.Repo,
  url: "ecto://postgres:postgres@localhost/scenario",
  pool: Ecto.Adapters.SQL.Sandbox,
  log: false
)

defmodule Scenario.Product do
  use Ecto.Schema

  schema "products" do
    field(:name, :string)

    timestamps()
  end
end

defmodule Scenario.Config do
  use Ecto.Schema

  schema "configs" do
    field(:lines, :string)

    timestamps()
  end
end

_ = Ecto.Adapters.Postgres.storage_down(Scenario.Repo.config())

:ok = Ecto.Adapters.Postgres.storage_up(Scenario.Repo.config())

{:ok, _pid} = Scenario.Repo.start_link()

:ok = Ecto.Migrator.up(Scenario.Repo, 0, Scenario.SetupMigration, log: false)

defmodule Main do
  import Ecto.Changeset
  
  def main do
    config = Scenario.Repo.insert!(%Scenario.Config{})
    
    changeset = Ecto.Changeset.change(%Scenario.Product{name: "123"}) |> unique_constraint([:name])
    
    Scenario.Repo.insert(changeset)

    Scenario.Repo.transaction(fn repo ->
      case repo.insert(changeset) do
        {:ok, product} ->
          IO.inspect(product, label: "PRODUCT OK")

        {:error, reason} ->
          IO.inspect(reason, label: "REASON")

          # mirror =
          #   mirror
          #   |> Map.put(:status, {:error, attrs})
          #   |> Map.put(:errors, errors)

          config_changeset = Ecto.Changeset.change(config, %{lines: "update"})

          repo.update(config_changeset)
      end
    end)
  end
end

Main.main
