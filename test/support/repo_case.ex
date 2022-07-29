defmodule EctoDiscriminator.RepoCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      alias EctoDiscriminator.Repo

      import Ecto
      import Ecto.Query
      import EctoDiscriminator.RepoCase

      # and any other stuff
    end
  end

  setup tags do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(EctoDiscriminator.Repo)

    unless tags[:async] do
      Ecto.Adapters.SQL.Sandbox.mode(EctoDiscriminator.Repo, {:shared, self()})
    end

    :ok
  end
end
