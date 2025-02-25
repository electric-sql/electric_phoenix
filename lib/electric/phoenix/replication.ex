if Code.ensure_loaded?(Electric.StackSupervisor) do
  defmodule Electric.Phoenix.Replication do
    @moduledoc """
    Entrypoint for including an embedded Electric instance into your `Phoenix`
    or `Plug` application.

        # application.ex
        children = [
          #...
          {Electric.Phoenix.Replication, repo: MyApp.Repo}
        ]

    This will start an Electric replication pipeline connected to the database
    configured for your `Ecto.Repo`.

    Now see `plug_opts/0` to configure your HTTP application.

    Note: The required functions in this module are aliased to `Electric.Phoenix` so 
    you can equally well do

        # application.ex
        children = [
          #...
          {Electric.Phoenix, repo: MyApp.Repo}
        ]

    ## Important

    If you override any other options , apart from database-related
    configuration (e.g. `repo`) then you **must** also use those configuration
    options in the `plug_opts/1` call to configure your HTTP stack.

    e.g.

        electric_config = [storage_dir: "/data", repo: MyApp.Repo]

        children = [
          {Electric.Phoenix, electric_config},
          {MyApp.Endpoint,
            electric: Electric.Phoenix.Replication.plug_opts(electric_config)}
        ]
    """
    @env Mix.env()

    @type configuration() :: keyword()
    @type configuration_opts() :: [{:repo, module()}, {:storage_dir, String.t()}]

    @doc false
    def child_spec(opts) do
      opts
      |> configuration()
      |> Electric.StackSupervisor.child_spec()
    end

    @doc false
    def start_link(opts) do
      Electric.StackSupervisor.start_link(opts)
    end

    @doc """
    Get a `Plug` or `Phoenix` endpoint configuration that works with
    `Electric.Phoenix` router integration.

    This configuration should be passed to your app under the `:electric` key.

    ### Phoenix

    To avoid the overhead of re-computing the configuration on every request,
    put the config into the Phoenix endpoint options in your application:

        # application.ex
        children = [
          #...
          {MyApp.Endpoint, electric: Electric.Phoenix.Replication.plug_opts()}
        ]

    ### Plug

    Pass the `electric` configuration to your main application Plug:

        # application.ex
        children = [
          #...
          {Bandit,
            plug: {MyApp.Router, electric: Electric.Phoenix.Replication.plug_opts()},
            port: 3000}
        ]

    """
    @spec plug_opts() :: [api: Electric.Shapes.Api.t()]
    def plug_opts do
      plug_opts(@env, [])
    end

    @spec plug_opts(atom(), keyword()) :: [api: Electric.Shapes.Api.t()]
    def plug_opts(env \\ @env, opts) do
      env
      |> core_configuration(opts)
      |> Electric.Application.api_plug_opts()
    end

    @spec configuration() :: configuration()
    def(configuration) do
      configuration(
        @env,
        Application.get_all_env(:electric)
      )
    end

    @spec configuration(atom(), configuration_opts()) :: configuration()
    def configuration(env \\ @env, opts)

    def configuration(env, opts) do
      env
      |> core_configuration(opts)
      |> expand_repo_opts()
      |> Electric.Application.configuration()
    end

    defp core_configuration(env, opts) do
      opts
      |> env_defaults(env)
      |> Keyword.put_new(:stack_id, "electric-embedded")
    end

    defp env_defaults(opts, :dev) do
      Keyword.put_new(
        opts,
        :storage_dir,
        Path.join(System.tmp_dir!(), "electric/shape-data#{System.monotonic_time()}")
      )
    end

    defp env_defaults(opts, :test) do
      stack_id = "electric-stack#{System.monotonic_time()}"

      opts
      |> Keyword.put(:stack_id, stack_id)
      |> Keyword.put(
        :storage,
        {Electric.ShapeCache.InMemoryStorage,
         table_base_name: :"electric-storage#{stack_id}", stack_id: stack_id}
      )
      |> Keyword.put(
        :persistent_kv,
        {Electric.PersistentKV.Memory, :new!, []}
      )
    end

    defp env_defaults(opts, _) do
      opts
    end

    defp expand_repo_opts(opts) do
      case Keyword.pop(opts, :repo, nil) do
        {nil, opts} ->
          opts

        {repo, opts} when is_atom(repo) ->
          repo_config = apply(repo, :config, [])

          Keyword.put(opts, :connection_opts, convert_repo_config(repo_config))
      end
    end

    defp convert_repo_config(repo_config) do
      expected_keys = Electric.connection_opts_schema() |> Keyword.keys()

      ssl_opts =
        case Keyword.get(repo_config, :ssl, nil) do
          off when off in [nil, false] -> [sslmode: :disable]
          true -> [sslmode: :require]
          _opts -> []
        end

      tcp_opts =
        if (:inet6 in dbg(Keyword.get(repo_config, :socket_options, []))) |> dbg,
          do: [ipv6: true],
          else: []

      repo_config
      |> Keyword.take(expected_keys)
      |> Keyword.merge(ssl_opts)
      |> Keyword.merge(tcp_opts)
      |> Electric.Utils.obfuscate_password()
    end
  end
end
