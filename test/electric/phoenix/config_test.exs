defmodule Electric.Phoenix.ReplicationTest do
  use ExUnit.Case, async: true

  Code.ensure_loaded!(Support.Repo)

  test "supports configuration via a Repo instance" do
    config =
      Electric.Phoenix.Replication.configuration(:prod,
        repo: Support.Repo,
        storage_dir: "/something"
      )
      |> Map.new()

    {pass_fun, connection_opts} = Keyword.pop!(config.connection_opts, :password)

    assert connection_opts == [
             username: "postgres",
             hostname: "localhost",
             database: "electric",
             port: 54321,
             sslmode: :require,
             ipv6: true
           ]

    assert pass_fun.() == "password"

    assert %{
             storage: {Electric.ShapeCache.FileStorage, [storage_dir: "/something"]},
             persistent_kv: %Electric.PersistentKV.Filesystem{root: "/something"}
           } = config
  end

  test "sets storage dir to system temp in dev" do
    config =
      Electric.Phoenix.Replication.configuration(:dev, repo: Support.Repo)
      |> Map.new()

    assert %{
             storage: {Electric.ShapeCache.FileStorage, [storage_dir: "/tmp/" <> storage_dir]},
             persistent_kv: %Electric.PersistentKV.Filesystem{
               root: "/tmp/" <> storage_dir
             }
           } = config
  end

  test "sets storage and kv to in-memory in test" do
    config =
      Electric.Phoenix.Replication.configuration(:test, repo: Support.Repo)
      |> Map.new()

    dbg(config)

    assert %{
             storage: {Electric.ShapeCache.InMemoryStorage, _},
             persistent_kv: %Electric.PersistentKV.Memory{}
           } = config
  end
end
