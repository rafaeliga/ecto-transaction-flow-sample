##########################################################################################
# REPRO SETUP
###########################################################################################

Mix.install([:jason, :ecto_sql, :postgrex, :flow])

defmodule Repo do
  use Ecto.Repo, otp_app: :scenario, adapter: Ecto.Adapters.Postgres
end

defmodule SetupMigration do
  use Ecto.Migration

  def change do
    create table(:posts) do
      add(:title, :string)
    end

    create(unique_index(:posts, [:title]))

    create table(:tags) do
      add(:name, :string)
    end
  end
end

Application.put_env(:scenario, Repo,
  url: "ecto://postgres:postgres@localhost/scenario",
  pool: Ecto.Adapters.SQL.Sandbox,
  log: false
)

defmodule Post do
  use Ecto.Schema

  schema "posts" do
    field(:title, :string)
  end
end

defmodule Tag do
  use Ecto.Schema

  schema "tags" do
    field(:name, :string)
  end
end

_ = Ecto.Adapters.Postgres.storage_down(Repo.config())

:ok = Ecto.Adapters.Postgres.storage_up(Repo.config())

{:ok, _pid} = Repo.start_link()

:ok = Ecto.Migrator.up(Repo, 0, SetupMigration, log: false)

##########################################################################################
# REPRO SCENARIO
###########################################################################################
defmodule Scenario do
  def run do
    tag = Repo.insert!(%Tag{})

    changeset =
      %Post{title: "123"}
      |> Ecto.Changeset.change()
      |> Ecto.Changeset.unique_constraint([:title])

    # INSERT THE POST FIRST SO IT TRIGGERS THE CONSTRAINT AFTER
    Repo.insert(changeset)

    Repo.transaction(fn repo ->
      # TRIES TO INSERT THE POST AGAIN AND SINCE THIS IS NOT AN UNHANDLED EXCEPTION
      # IT SHOULD NOT GENERATE A ROLLBACK (OR SHOULD IT!?)
      case repo.insert(changeset) do
        {:ok, post} ->
          IO.inspect(post, label: "POST")

        {:error, changeset} ->
          IO.inspect(changeset, label: "CHANGESET")

          tag
          |> Ecto.Changeset.change(%{name: "failed"})
          |> repo.update()
      end
    end)
  end
end

Scenario.run()
