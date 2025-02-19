defmodule Electric.Phoenix.ServeShapePlugTest do
  use ExUnit.Case, async: true
  use Plug.Test

  alias Electric.Shapes.Api

  import Mox
  import Support.DbSetup
  import Support.ElectricHelpers

  require Phoenix.ConnTest

  @endpoint Electric.Phoenix.LiveViewTest.Endpoint
  @registry __MODULE__.Registry

  Code.ensure_loaded(Support.User)

  defmodule MyEnv do
    def client!(opts \\ []) do
      Electric.Client.new!(
        base_url: "https://cloud.electric-sql.com",
        authenticator:
          Keyword.get(
            opts,
            :authenticator,
            {Electric.Client.Authenticator.MockAuthenticator, salt: "my-salt"}
          )
      )
    end

    def authenticate(conn, shape, opts \\ [])

    def authenticate(%Plug.Conn{} = conn, %Electric.Client.ShapeDefinition{} = shape, opts) do
      mode = Keyword.get(opts, :mode, :fun)

      %{
        "shape-auth-mode" => to_string(mode),
        "shape-auth-path" => conn.request_path,
        "shape-auth-table" => shape.table
      }
    end
  end

  setup :verify_on_exit!

  setup do
    start_link_supervised!({Registry, keys: :duplicate, name: @registry})
    :ok
  end

  setup [:with_stack_id_from_test, :with_unique_db, :with_stack, :with_table]

  defmodule MyEnv.TestRouter do
    use Plug.Router, copy_opts_to_assign: :config
    use Electric.Phoenix.Plug.Shapes, path: "/shapes"

    plug(:match)
    plug(:dispatch)
  end

  defp call(conn, plug \\ MyEnv.TestRouter, ctx) do
    opts = Api.plug_opts(electric_opts(ctx))

    plug.call(conn, electric: opts)
  end

  describe "Plug" do
    @tag table: {
           "things",
           ["id int8 not null primary key generated always as identity", "value text"]
         }
    test "provides the standard electric http api", ctx do
      Postgrex.query!(
        ctx.db_conn,
        """
        insert into things (value) values ('one'), ('two'), ('three');
        """,
        []
      )

      resp =
        conn(:get, "/shapes", %{"table" => "things", "offset" => "-1"})
        |> call(ctx)

      assert resp.status == 200
      assert Plug.Conn.get_resp_header(resp, "electric-offset") == ["0_0"]

      assert [
               %{"headers" => %{"operation" => "insert"}, "value" => %{"value" => "one"}},
               %{"headers" => %{"operation" => "insert"}, "value" => %{"value" => "two"}},
               %{"headers" => %{"operation" => "insert"}, "value" => %{"value" => "three"}}
             ] = Jason.decode!(resp.resp_body)
    end
  end

  describe "Phoenix" do
    setup(ctx) do
      Application.put_all_env(electric: electric_opts(ctx))
    end

    @tag table: {
           "things",
           ["id int8 not null primary key generated always as identity", "value text"]
         }
    test "works", ctx do
      Postgrex.query!(
        ctx.db_conn,
        """
        insert into things (value) values ('one'), ('two'), ('three');
        """,
        []
      )

      resp =
        Phoenix.ConnTest.build_conn()
        |> Phoenix.ConnTest.get("/api", %{table: "things", offset: "-1"})

      assert resp.status == 200
      assert Plug.Conn.get_resp_header(resp, "electric-offset") == ["0_0"]

      assert [
               %{"headers" => %{"operation" => "insert"}, "value" => %{"value" => "one"}},
               %{"headers" => %{"operation" => "insert"}, "value" => %{"value" => "two"}},
               %{"headers" => %{"operation" => "insert"}, "value" => %{"value" => "three"}}
             ] = Jason.decode!(resp.resp_body)
    end
  end
end
