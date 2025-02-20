if Code.ensure_loaded?(Electric.Shapes.Api) do
  defmodule Electric.Phoenix.Plug.Shapes do
    @moduledoc """
    A `Plug.Router` and `Phoenix.Router` compatible Plug handler that allows
    you to mount the full Electric shape api into your application.

    Unlike `Electric.Phoenix.Router.shape/2` this allows your app to serve
    shapes defined by `table` parameters, much like the Electric application.

    The advantage is that you're free to put your own authentication and
    authorization Plugs in front of this endpoint, integrating the auth for
    your shapes API with the rest of your app.

    ## Configuration

    Before configuring your router, you must install and configure the
    `:electric` application.

    See the documentation for [embedding electric](`Electric.Phoenix`) for
    details on embedding Electric into your Elixir application.

    ## Plug Integration

    Mount this Plug into your router using `Plug.Router.forward/2`.

        defmodule MyRouter do
          use Plug.Router, copy_opts_to_assign: :config
          use Electric.Phoenix.Plug.Shapes

          plug :match
          plug :dispatch

          forward "/shapes",
            to: Electric.Phoenix.Plug.Shapes,
            init_opts: [opts_in_assign: :config]
        end

    You **must** configure your `Plug.Router` with `copy_opts_to_assign` and
    pass the key you configure here (in this case `:config`) to the
    `Electric.Phoenix.Plug.Shapes` plug in it's `init_opts`.

    In your application, build your Electric confguration using `Electric.Application.api_plug_opts/0` and pass the result to your router as `electric`:

        # in application.ex
        def start(_type, _args) do
          electric_config = Electric.Application.api_plug_opts()

          children = [
            {Bandit, plug: {MyRouter, electric: electric_config}, port: 4000}
          ]

          Supervisor.start_link(children, strategy: :one_for_one, name: MyApp.Supervisor)
        end

    ## Phoenix Integration

    Use `Phoenix.Router.forward/2` in your router:

        defmodule MyAppWeb.Router do
          use Phoenix.Router

          pipeline :shapes do
            # your authz plugs
          end

          scope "/shapes" do
            pipe_through [:shapes]

            forward "/", Electric.Phoenix.Plug.Shapes
          end
        end

    As for the Plug integration, include the Electric configuration at runtime
    within the `Application.start/2` callback.

        # in application.ex
        def start(_type, _args) do
          electric_config = Electric.Application.api_plug_opts()

          children = [
            # ...
            {MyAppWeb.Endpoint, electric: electric_config}
          ]

          Supervisor.start_link(children, strategy: :one_for_one, name: MyApp.Supervisor)
        end

    """

    alias Electric.Shapes.Api
    alias Electric.Plug.{ServeShapePlug, DeleteShapePlug, OptionsShapePlug}

    defmacro __using__(_opts \\ []) do
      Electric.Phoenix.Plug.Utils.env!(__CALLER__)

      quote do
        Electric.Phoenix.Plug.Utils.opts_in_assign!(
          [],
          __MODULE__,
          Electric.Phoenix.Plug.Shapes
        )
      end
    end

    @behaviour Plug

    def init(opts), do: Map.new(opts)

    def call(%{private: %{phoenix_endpoint: endpoint}} = conn, _config) do
      config = endpoint.config(:electric)

      serve_api(conn, config)
    end

    def call(conn, %{opts_in_assign: key}) do
      api =
        get_in(conn.assigns, [key, :electric, :api]) ||
          raise "Unable to retrieve the Electric API configuration from the assigns"

      serve_api(conn, api)
    end

    @doc false
    def serve_api(%{method: "GET"} = conn, %Api{} = api) do
      ServeShapePlug.call(conn, ServeShapePlug.init(api: api))
    end

    def serve_api(%{method: "DELETE"} = conn, %Api{} = api) do
      DeleteShapePlug.call(conn, DeleteShapePlug.init(api: api))
    end

    def serve_api(%{method: "OPTIONS"} = conn, %Api{} = api) do
      OptionsShapePlug.call(conn, OptionsShapePlug.init(api: api))
    end

    def serve_api(conn, opts) do
      api = opts[:api] || raise "No API configured in plug options"
      serve_api(conn, api)
    end
  end
end
