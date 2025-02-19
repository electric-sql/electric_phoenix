defmodule Support.ElectricHelpers do
  alias Electric.Postgres.Inspector.EtsInspector
  alias Electric.Shapes.Api

  def with_stack_id_from_test(ctx) do
    stack_id = full_test_name(ctx)
    registry_name = Electric.ProcessRegistry.registry_name(stack_id)

    # registry =
    # ExUnit.Callbacks.start_link_supervised!({Electric.ProcessRegistry, name: registry_name, stack_id: stack_id})

    [stack_id: stack_id, process_registry: registry_name]
  end

  def with_stack(%{stack_id: stack_id} = ctx) do
    kv = %Electric.PersistentKV.Memory{
      parent: self(),
      pid: ExUnit.Callbacks.start_supervised!(Electric.PersistentKV.Memory, restart: :temporary)
    }

    storage =
      Electric.ShapeCache.Storage.shared_opts(
        {Electric.ShapeCache.InMemoryStorage,
         stack_id: stack_id, table_base_name: :"in_memory_storage_#{stack_id}"}
      )

    publication_name = "electric_test_pub_#{:erlang.phash2(stack_id)}"

    stack_events_registry = :"Registry.StackEvents:#{stack_id}"
    ExUnit.Callbacks.start_supervised!({Registry, name: stack_events_registry, keys: :duplicate})

    ref =
      Electric.StackSupervisor.subscribe_to_stack_events(stack_events_registry, stack_id)

    stack_supervisor =
      ExUnit.Callbacks.start_link_supervised!(
        {Electric.StackSupervisor,
         stack_id: stack_id,
         persistent_kv: kv,
         storage: storage,
         connection_opts: ctx.db_config,
         stack_events_registry: stack_events_registry,
         replication_opts: [
           slot_name: "electric_test_slot_#{:erlang.phash2(stack_id)}",
           publication_name: publication_name,
           try_creating_publication?: true,
           slot_temporary?: true
         ],
         pool_opts: [
           backoff_type: :stop,
           max_restarts: 0,
           pool_size: 2
         ]}
      )

    receive do
      {:stack_status, ^ref, :ready} -> :ok
    after
      2000 ->
        raise "Stack not ready"
    end

    %{
      registry: Electric.StackSupervisor.registry_name(stack_id),
      shape_cache: {Electric.ShapeCache, [stack_id: stack_id]},
      persistent_kv: kv,
      storage: storage,
      stack_events_registry: stack_events_registry,
      stack_supervisor: stack_supervisor,
      inspector:
        {EtsInspector, stack_id: stack_id, server: EtsInspector.name(stack_id: stack_id)},
      publication_name: publication_name
    }
  end

  defp full_test_name(ctx) do
    "#{ctx.module} #{ctx.test}"
  end

  def electric_opts(ctx) do
    [
      stack_id: ctx.stack_id,
      provided_database_id: ctx.stack_id,
      pg_id: nil,
      stack_events_registry: ctx.stack_events_registry,
      shape_cache: ctx.shape_cache,
      storage: ctx.storage,
      inspector: ctx.inspector,
      persistent_kv: ctx.persistent_kv,
      registry: ctx.registry,
      stack_ready_timeout: Access.get(ctx, :stack_ready_timeout, 100),
      long_poll_timeout: long_poll_timeout(ctx),
      max_age: max_age(ctx),
      stale_age: stale_age(ctx)
    ]
  end

  def with_api_server(ctx) do
    port = 33000

    # Electric.Phoenix.plug_config(
    electric_opts = Api.plug_opts(electric_opts(ctx))

    ExUnit.Callbacks.start_link_supervised!(
      {Bandit, plug: {MyEnv.TestRouter, electric: electric_opts}, port: port}
    )

    [port: port]
  end

  defp max_age(ctx), do: Access.get(ctx, :max_age, 60)
  defp stale_age(ctx), do: Access.get(ctx, :stale_age, 300)
  defp long_poll_timeout(ctx), do: Access.get(ctx, :long_poll_timeout, 20_000)
end
