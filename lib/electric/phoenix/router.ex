defmodule Electric.Phoenix.Router do
  defmacro shape(path) do
    route(path, build_definition(path, __CALLER__, []))
  end

  defmacro shape(path, opts) when is_list(opts) do
    route(path, build_definition(path, __CALLER__, opts))
  end

  # e.g. shape "/path", Ecto.Query.from(t in MyTable)
  defmacro shape(path, queryable) when is_tuple(queryable) do
    route(path, build_shape_from_query(queryable, __CALLER__, []))
  end

  # e.g. shape "/path", Ecto.Query.from(t in MyTable), replica: :full
  defmacro shape(path, queryable, opts) when is_tuple(queryable) and is_list(opts) do
    route(path, build_shape_from_query(queryable, __CALLER__, opts))
  end

  defp route(path, definition) do
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
    clean_path = path |> strip_leading_slashes() |> strip_trailing_slashes()

    # Don't accept paths containing slashes as implicit table names
    # because in a router context `/` will mean sub-path more than table name.
    # We could take the last part of any path as the implicit table name
    # but it's better to require an explicit `:table` option I think.
    if String.contains?(clean_path, "/") do
      :error
    else
      {:ok, clean_path}
    end
  end

  defp strip_leading_slashes(path), do: String.trim_leading(path, "/")
  defp strip_trailing_slashes(path), do: String.trim_trailing(path, "/")

  defmodule Shape do
    alias Electric.Shapes
    alias Electric.Plug.ServeShapePlug

    @behaviour Plug

    def init(opts), do: opts

    def call(%{private: %{phoenix_endpoint: endpoint}} = conn, %{shape: shape}) do
      config = endpoint.config(:electric)

      {:ok, shape_api} =
        config
        |> Keyword.fetch!(:api)
        |> Shapes.Api.predefined_shape(shape)

      ServeShapePlug.call(conn, ServeShapePlug.init(api: shape_api))
    end
  end
end
