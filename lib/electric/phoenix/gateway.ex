defmodule Electric.Phoenix.Gateway do
  @moduledoc false

  alias Electric.Client
  alias Electric.Client.Fetch
  alias Electric.Client.ShapeDefinition

  require Ecto.Query

  @type configuration :: %{url: binary(), headers: %{binary() => binary()}, where: binary()}

  @doc false
  @spec configuration(Client.t(), ShapeDefinition.t()) :: configuration()
  def configuration(%Client{} = client, %Client.ShapeDefinition{} = shape) do
    request = Client.request(client, shape: shape)
    auth_headers = Client.authenticate_shape(client, shape)
    shape_params = ShapeDefinition.params(shape)
    url = Fetch.Request.url(request, query: false)

    Map.merge(%{url: url, headers: auth_headers}, shape_params)
  end

  @doc false
  @spec dynamic_shape(Plug.Conn.t(), Ecto.Queryable.t(), Keyword.t()) :: ShapeDefinition.t()
  def dynamic_shape(conn, query, params) do
    conn = Plug.Conn.fetch_query_params(conn)

    Enum.reduce(params, query, fn
      {column, [{op, param}]}, query ->
        value = conn.params[to_string(param)]

        add_filter(query, column, op, value)

      {column, param}, query ->
        value = conn.params[to_string(param)]
        add_filter(query, column, :==, value)
    end)
    |> Electric.Client.shape!()
  end

  defp add_filter(query, column, :==, value) do
    Ecto.Query.from(q in query, where: field(q, ^column) == ^value)
  end

  defp add_filter(query, column, :>, value) do
    Ecto.Query.from(q in query, where: field(q, ^column) > ^value)
  end

  defp add_filter(query, column, :<, value) do
    Ecto.Query.from(q in query, where: field(q, ^column) < ^value)
  end

  defp add_filter(query, column, :!=, value) do
    Ecto.Query.from(q in query, where: field(q, ^column) != ^value)
  end

  defp add_filter(query, column, :>=, value) do
    Ecto.Query.from(q in query, where: field(q, ^column) >= ^value)
  end

  defp add_filter(query, column, :<=, value) do
    Ecto.Query.from(q in query, where: field(q, ^column) <= ^value)
  end
end
