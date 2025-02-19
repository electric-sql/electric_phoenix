defmodule Electric.Phoenix.LiveViewTest.Router do
  use Phoenix.Router

  import Phoenix.LiveView.Router
  import Electric.Phoenix.Router

  pipeline :setup_session do
    plug Plug.Session,
      store: :cookie,
      key: "_live_view_key",
      signing_salt: "/VEDsdfsffMnp5"

    plug :fetch_session
  end

  pipeline :browser do
    plug :setup_session
    plug :accepts, ["html"]
    plug :fetch_live_flash
  end

  scope "/", Electric.Phoenix.LiveViewTest do
    pipe_through [:browser]

    live "/stream", StreamLive
    live "/stream/with-component", StreamLiveWithComponent
  end

  scope "/" do
    pipe_through [:browser]

    get "/shape/items", Electric.Phoenix.Plug,
      shape: Electric.Client.shape!("items", where: "visible = true")

    get "/shape/generic", Electric.Phoenix.Plug, []
  end

  scope "/shape" do
    # by default we take the table name from the path
    # note that this does not handle weird table names that need quoting
    # or namespaces
    shape "/todos"

    # or we can expliclty specify the table
    shape "/things-to-do", table: "todos"

    # to use a non-standard namespace, we include it
    # so in this case the table is "food"."toeats"
    shape "/toeats", namespace: "food"

    # or we can expliclty specify the table
    shape "/ideas",
      where: "plausible = true",
      columns: ["id", "title"],
      replica: :full,
      storage: %{compaction: :disabled}
  end

  scope "/api" do
    pipe_through [:browser]

    forward "/", Electric.Phoenix.Plug.Shapes, []
  end
end
