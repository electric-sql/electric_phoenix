defmodule Electric.Phoenix.Gateway do
  @moduledoc false

  alias Electric.Client
  alias Electric.Client.Fetch
  alias Electric.Client.ShapeDefinition

  require Ecto.Query

  @valid_ops [:==, :!=, :>, :<, :>=, :<=]

  @type shape_definition :: Ecto.Queryable.t() | Client.ShapeDefinition.t()
  @type configuration :: %{url: binary(), headers: %{binary() => binary()}, where: binary()}
  @type table_column :: atom()
  @type param_name :: atom()
  @type op :: :== | :!= | :> | :< | :>= | :<=
  @type conn_param_spec :: param_name() | [{op(), param_name()}]
  @type dynamic_shape_param :: {table_column(), conn_param_spec()} | table_column()
  @type dynamic_shape_params :: [dynamic_shape_param()]

  @spec configuration(shape_definition(), Client.t()) :: configuration()
  def configuration(shape_or_queryable, client \\ Electric.Phoenix.client!())

  @doc false
  def configuration(%Client.ShapeDefinition{} = shape, %Client{} = client) do
    request = Client.request(client, shape: shape)
    auth_headers = Client.authenticate_shape(client, shape)
    shape_params = ShapeDefinition.params(shape, format: :json)
    url = Fetch.Request.url(request, query: false)

    Map.merge(%{url: url, headers: auth_headers}, shape_params)
  end

  def configuration(%Ecto.Query{} = query, %Client{} = client) do
    query
    |> Electric.Client.shape!()
    |> configuration(client)
  end

  def configuration(module, %Client{} = client) when is_atom(module) do
    module
    |> Electric.Client.shape!()
    |> configuration(client)
  end

  @doc """
  Defines a shape based on a root `Ecto` query plus some filters based on the
  current request.

      forward "/shapes/tasks/:project_id",
        to: Electric.Gateway.Plug,
        shape: Electric.Phoenix.Gateway.shape!(
          from(t in Task, where: t.active == true),
          project_id: :project_id
        )

  The `params` describe the way to build the `where` clause on the shape from
  the request parameters.

  For example, `[id: :user_id]` means that the `id` column on the table should
  match the value of the `user_id` parameter, equivalent to:

      from(
        t in Table,
        where: t.id == ^conn.params["user_id"]
      )

  If both the table column and the request parameter have the same name, then
  you can just pass the name, so:

      Electric.Phoenix.Gateway.shape!(Table, [:visible])

  is equivalent to:

      from(
        t in Table,
        where: t.visible == ^conn.params["visible"]
      )

  If you need to match on something other than `==` then you can pass the operator in the params:

      Electric.Phoenix.Gateway.shape!(Table, size: [>=: :size])

  is equivalent to:

      from(
        t in Table,
        where: t.size >= ^conn.params["size"]
      )

  Instead of calling `shape!/2` directly in your route definition, you can just
  pass a list of `[query | params]` to do the same thing:

      forward "/shapes/tasks/:project_id",
        to: Electric.Gateway.Plug,
        shape: [
          from(t in Task, where: t.active == true),
          project_id: :project_id
        ]

  """
  @spec shape!(shape_definition(), dynamic_shape_params()) :: term()
  def shape!(query, params) when is_list(params) do
    [query | params]
  end

  @doc ~S"""
  Send the client configuration for a given shape to the browser.

  ## Example

      get "/my-shapes/messages" do
        user_id = get_session(conn, :user_id)
        shape = from(m in Message, where: m.user_id == ^user_id)
        Electric.Gateway.send_configuration(conn, shape)
      end

      get "/my-shapes/tasks/:project_id" do
        project_id = conn.params["project_id"]

        if user_has_access_to_project?(project_id) do
          shape = where(Task, project_id: ^project_id)
          Electric.Gateway.send_configuration(conn, shape)
        else
          send_resp(conn, :forbidden, "You do not have permission to view project #{project_id}")
        end
      end

  """
  @spec send_configuration(Plug.Conn.t(), shape_definition(), Client.t()) :: Plug.Conn.t()
  def send_configuration(conn, shape_or_queryable, client \\ Electric.Phoenix.client!())

  def send_configuration(conn, shape_or_queryable, client) do
    configuration = configuration(shape_or_queryable, client)

    conn
    |> Plug.Conn.put_resp_content_type("application/json")
    |> Plug.Conn.send_resp(200, Jason.encode!(configuration))
  end

  @doc false
  def validate_dynamic_opts(opts) do
    Enum.map(opts, fn
      {column, param} when is_atom(param) ->
        {column, param}

      {column, [{op, param}]} when is_atom(param) and op in @valid_ops ->
        {column, {op, param}}

      column when is_atom(column) ->
        {column, column}
    end)
  end

  @doc false
  @spec dynamic_shape(Plug.Conn.t(), Ecto.Queryable.t(), Keyword.t()) :: Plug.Conn.t()
  def dynamic_shape(conn, query, params) do
    conn = Plug.Conn.fetch_query_params(conn)

    shape =
      Enum.reduce(params, query, fn
        {column, {op, param}}, query ->
          value = conn.params[to_string(param)]

          add_filter(query, column, op, value)

        {column, param}, query ->
          value = conn.params[to_string(param)]
          add_filter(query, column, :==, value)
      end)
      |> Electric.Client.shape!()

    Plug.Conn.assign(conn, :shape, shape)
  end

  for op <- @valid_ops do
    where =
      {op, [],
       [
         {:field, [], [Macro.var(:q, nil), {:^, [], [Macro.var(:column, nil)]}]},
         {:^, [], [Macro.var(:value, nil)]}
       ]}

    defp add_filter(query, var!(column), unquote(op), var!(value)) do
      Ecto.Query.where(query, [q], unquote(where))
    end
  end
end
