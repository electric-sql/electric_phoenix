defmodule Electric.Phoenix.Plug do
  @moduledoc """
  Provides an configuration endpoint for use in your Phoenix applications.

  Rather than configuring your [Electric Typescript
  client](https://electric-sql.com/docs/api/clients/typescript) directly, you
  instead configure a route in your application with a pre-configured
  `Electric.Client.ShapeDefinition` and then retreive the URL and other
  configuration for that shape from your client via a request to your Phoenix
  application.

  In your Phoenix application, [add a route](https://hexdocs.pm/phoenix/Phoenix.Router.html) to
  `Electric.Phoenix.Gateway.Plug` specifying a particular shape:

      defmodule MyAppWeb.Router do
        scope "/shapes" do
          pipe_through :browser

          get "/todos", Electric.Phoenix.Gateway.Plug,
            shape: Electric.Client.shape!("todos", where: "visible = true")
        end
      end

  Then in your client code, you retrieve the shape configuration directly
  from the Phoenix endpoint:

  ``` typescript
  import { ShapeStream } from '@electric-sql/client'

  const endpoint = `https://localhost:4000/shapes/todos`
  const response = await fetch(endpoint)
  const config = await response.json()

  // The returned `config` has all the information you need to subscribe to
  // your shape
  const stream = new ShapeStream(config)

  stream.subscribe(messages => {
    // ...
  })
  ```

  You can add additional authentication/authorization for shapes using
  [Phoenix's
  pipelines](https://hexdocs.pm/phoenix/Phoenix.Router.html#pipeline/2) or
  other [`plug`
  calls](https://hexdocs.pm/phoenix/Phoenix.Router.html#plug/2).

  ## Plug.Router

  For  pure `Plug`-based applications, you can use `Plug.Router.forward/2`:

      defmodule MyRouter do
        use Plug.Router

        plug :match
        plug :dispatch

        forward "/shapes/items",
          to: Electric.Phoenix.Gateway.Plug,
          shape: Electric.Client.shape!("items")

        match _ do
          send_resp(conn, 404, "oops")
        end
      end

  ## Parameter-based shapes

  As well as defining fixed-shapes for a particular url, you can request
  shape configuration using parameters in your request:

      defmodule MyAppWeb.Router do
        scope "/" do
          pipe_through :browser

          get "/shape", Electric.Phoenix.Gateway.Plug, []
        end
      end

  ``` typescript
  import { ShapeStream } from '@electric-sql/client'

  const endpoint = `https://localhost:4000/shape?table=items&namespace=public&where=visible%20%3D%20true`
  const response = await fetch(endpoint)
  const config = await response.json()

  // as before
  ```

  The parameters are:

  - `table` - The Postgres table name (required).
  - `namespace` - The Postgres schema if not specified defaults to `public`.
  - `where` - The [where clause](https://electric-sql.com/docs/guides/shapes#where-clause) to filter items from the shape.
  """

  use Elixir.Plug.Builder, copy_opts_to_assign: :config

  alias Electric.Client.ShapeDefinition
  alias Electric.Phoenix.Gateway

  plug :fetch_query_params
  plug :shape_definition
  plug :return_configuration

  @doc false
  def init(opts) do
    shape_opts =
      case Keyword.get(opts, :shape) do
        nil ->
          %{}

        table_name when is_binary(table_name) ->
          %{shape: Electric.Client.shape!(table_name)}

        %ShapeDefinition{} = shape ->
          %{shape: shape}

        %Ecto.Query{} = query ->
          %{shape: Electric.Client.shape!(query)}

        schema when is_atom(schema) ->
          %{shape: Electric.Client.shape!(schema)}

        [query | opts] when is_struct(query, Ecto.Query) or is_atom(query) ->
          opts = Gateway.validate_dynamic_opts(opts)
          %{shape: {:dynamic, query, opts}}
      end

    # Unless the client is defined at compile time, unlikely in prod
    # environments because the app will probably be using configuration from
    # the environment, we need to use a function to instantiate the client at
    # runtime.
    Map.merge(
      %{client: Keyword.get(opts, :client, &Electric.Phoenix.client!/0)},
      shape_opts
    )
  end

  @doc false
  def return_configuration(conn, _opts) do
    shape = conn.assigns.shape
    client = get_in(conn.assigns, [:config, :client]) |> build_client()
    config = Gateway.configuration(shape, client)

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(config))
  end

  @doc false
  def shape_definition(conn, opts)

  # the app has configured a fixed shape for the endpoint
  def shape_definition(%{assigns: %{shape: %ShapeDefinition{}}} = conn, _opts) do
    conn
  end

  def shape_definition(%{assigns: %{config: %{shape: %ShapeDefinition{} = shape}}} = conn, _opts) do
    assign(conn, :shape, shape)
  end

  def shape_definition(%{assigns: %{config: %{shape: {:dynamic, query, opts}}}} = conn, _opts) do
    Gateway.dynamic_shape(conn, query, opts)
  end

  def shape_definition(%{query_params: %{"table" => table}} = conn, _opts) do
    case ShapeDefinition.new(table,
           where: conn.params["where"],
           namespace: conn.params["namespace"]
         ) do
      {:ok, shape} ->
        assign(conn, :shape, shape)

      {:error, error} ->
        halt_with_error(conn, Exception.message(error))
    end
  end

  def shape_definition(conn, _opts) do
    halt_with_error(conn, "Missing required parameter \"table\"")
  end

  defp build_client(%Electric.Client{} = client) do
    client
  end

  defp build_client(client_fun) when is_function(client_fun, 0) do
    client_fun.()
  end

  defp halt_with_error(conn, status \\ 400, reason) when is_binary(reason) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, Jason.encode!(%{error: reason}))
    |> halt()
  end
end
