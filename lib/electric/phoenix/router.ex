if Code.ensure_loaded?(Electric.Shapes.Api) do
  defmodule Electric.Phoenix.Router do
    @moduledoc """
    Provides router macros to simplify the exposing of Electric shape streams
    within your Phoenix or Plug application.

    ## Phoenix Integration

    When using within a Phoenix application, you should just import the macros
    defined here

        import #{__MODULE__}

    ## Plug Integration

    Within Plug applications you need to do a little more work.



    **Note:** If you use Ecto queries in your shape definitions, e.g.

        shape "/todos",
          Ecto.Query.from(t in MyApp.Todos, where: t.completed == false)

    and you get the error `error: undefined variable "t"` it's because you forgot
    to require the Ecto.Query module. Above your shape route add:

        require Ecto.Query

    """

    import Electric.Phoenix.Plug.Utils

    # The reason to require `use` for the plug version is so that we can do some
    # validation of our environment, specifically we need the
    # `:copy_opts_to_assign` option to be set so we receive the
    # runtime-configured electric config in our plug without having to call the
    # api configuration function on every request
    defmacro __using__(opts \\ []) do
      # validate that we're being used in the context of a Plug.Router impl
      Electric.Phoenix.Plug.Utils.env!(__CALLER__)

      quote do
        # save this config value for use in our route/2 quoted expression
        @electric_assign_opts Electric.Phoenix.Plug.Utils.opts_in_assign!(
                                unquote(opts),
                                __MODULE__,
                                Electric.Phoenix.Router
                              )

        import Electric.Phoenix.Router
      end
    end

    @doc """

    """
    defmacro shape(path) do
      route(env!(__CALLER__), path, build_definition(path, __CALLER__, []))
    end

    defmacro shape(path, opts) when is_list(opts) do
      route(env!(__CALLER__), path, build_definition(path, __CALLER__, opts))
    end

    # e.g. shape "/path", Ecto.Query.from(t in MyTable)
    defmacro shape(path, queryable) when is_tuple(queryable) do
      route(env!(__CALLER__), path, build_shape_from_query(queryable, __CALLER__, []))
    end

    # e.g. shape "/path", Ecto.Query.from(t in MyTable), replica: :full
    defmacro shape(path, queryable, opts) when is_tuple(queryable) and is_list(opts) do
      route(env!(__CALLER__), path, build_shape_from_query(queryable, __CALLER__, opts))
    end

    defp route(:plug, path, definition) do
      quote do
        Plug.Router.match(unquote(path),
          via: :get,
          to: Electric.Phoenix.Router.Shape,
          init_opts: %{shape: unquote(definition), plug_opts_assign: @electric_assign_opts}
        )
      end
    end

    defp route(:phoenix, path, definition) do
      quote do
        Phoenix.Router.match(
          :get,
          unquote(path),
          Electric.Phoenix.Router.Shape,
          %{shape: unquote(definition)},
          []
        )
      end
    end

    defp build_definition(path, caller, opts) when is_list(opts) do
      case Keyword.fetch(opts, :query) do
        {:ok, queryable} ->
          build_shape_from_query(queryable, caller, opts)

        :error ->
          define_shape(path, opts)
      end
    end

    defp build_shape_from_query(queryable, caller, opts) do
      # build the shape definition from the query at compile time, to avoid
      # runtime overhead since the query is in the router and not depending on
      # runtime variables I think this is not problematic
      {query, _binding} = Code.eval_quoted(queryable, [], caller)

      %{table: table, namespace: namespace, where: where, columns: columns} =
        Electric.Client.EctoAdapter.shape_from_query!(query)

      [
        relation: {namespace || "public", table},
        where: where,
        columns: columns
      ]
      |> maybe_put(:storage, opts)
      |> maybe_put(:replica, opts)
    end

    defp define_shape(path, opts) do
      relation = build_relation(path, opts)

      [relation: relation]
      |> maybe_put(:where, opts)
      |> maybe_put(:columns, opts)
      |> maybe_put(:replica, opts)
      |> maybe_put(:storage, opts)
    end

    defp maybe_put(params, key, opts) do
      case Keyword.fetch(opts, key) do
        {:ok, value} -> Keyword.put(params, key, value)
        :error -> params
      end
    end

    defp build_relation(path, opts) do
      case Keyword.fetch(opts, :table) do
        {:ok, table} ->
          table

        :error ->
          case table_from_path(path) do
            {:ok, table} ->
              table

            :error ->
              raise ArgumentError,
                message:
                  "No valid table specified. The path #{inspect(path)} is not a valid table name and no `:table` option passed."
          end
      end
      |> add_namespace(opts)
    end

    defp add_namespace(table, opts) do
      {Keyword.get(opts, :namespace, "public"), table}
    end

    defp table_from_path(path) do
      path
      |> strip_leading_slashes()
      |> strip_trailing_slashes()
      |> Path.split()
      |> case do
        [] ->
          :error

        parts ->
          {:ok, Enum.at(parts, -1)}
      end
    end

    defp strip_leading_slashes(path), do: String.trim_leading(path, "/")
    defp strip_trailing_slashes(path), do: String.trim_trailing(path, "/")

    defmodule Shape do
      alias Electric.Shapes

      @behaviour Plug

      def init(opts), do: opts

      def call(%{private: %{phoenix_endpoint: endpoint}} = conn, %{shape: shape}) do
        config = endpoint.config(:electric)
        api = Keyword.fetch!(config, :api)

        serve_shape(conn, api, shape)
      end

      def call(conn, %{shape: shape, plug_opts_assign: assign_key}) do
        api =
          get_in(conn.assigns, [assign_key, :electric, :api]) ||
            raise RuntimeError,
              message:
                "Please configure your Router opts with [electric: Electric.Shapes.Api.plug_opts()]"

        serve_shape(conn, api, shape)
      end

      defp serve_shape(conn, api, shape) do
        {:ok, shape_api} = Shapes.Api.predefined_shape(api, shape)

        Electric.Phoenix.Plug.Shapes.serve_api(conn, shape_api)
      end
    end
  end
end
