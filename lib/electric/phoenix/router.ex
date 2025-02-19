defmodule Electric.Phoenix.Router do
  defmacro shape(path, opts \\ []) do
    relation = build_relation(path, opts)

    definition =
      [relation: relation]
      |> maybe_put(:where, opts)
      |> maybe_put(:columns, opts)
      |> maybe_put(:replica, opts)
      |> maybe_put(:storage, opts)

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

    @behaviour Plug

    def init(opts), do: opts

    def call(%{private: %{phoenix_endpoint: endpoint}} = conn, %{shape: shape}) do
      {_time, config} =
        :timer.tc(fn ->
          endpoint.config(:electric)
        end)

      {:ok, shape_api} =
        config
        |> Keyword.fetch!(:api)
        |> Shapes.Api.predefined_shape(shape)

      Electric.Plug.ServeShapePlug.call(conn, Electric.Plug.ServeShapePlug.init(api: shape_api))
    end
  end
end
