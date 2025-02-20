defmodule Electric.Phoenix.RouterTest do
  use ExUnit.Case, async: true
  use Plug.Test

  alias Electric.Shapes

  import Support.DbSetup
  import Support.ElectricHelpers

  require Phoenix.ConnTest

  @registry __MODULE__.Registry
  @endpoint Electric.Phoenix.LiveViewTest.Endpoint

  Code.ensure_compiled!(Support.Todo)

  setup do
    start_link_supervised!({Registry, keys: :duplicate, name: @registry})
    :ok
  end

  setup [:with_stack_id_from_test, :with_unique_db, :with_stack, :with_table, :with_data]

  setup(ctx) do
    Application.put_all_env(electric: electric_opts(ctx))
  end

  describe "Phoenix.Router - shape/2" do
    @tag table: {
           "todos",
           [
             "id int8 not null primary key generated always as identity",
             "title text",
             "completed boolean default false"
           ]
         }
    @tag data: {"todos", ["title"], [["one"], ["two"], ["three"]]}

    test "uses path as table name by default", _ctx do
      resp =
        Phoenix.ConnTest.build_conn()
        |> Phoenix.ConnTest.get("/shape/todos", %{offset: "-1"})

      assert resp.status == 200
      assert Plug.Conn.get_resp_header(resp, "electric-offset") == ["0_0"]

      assert [
               %{"headers" => %{"operation" => "insert"}, "value" => %{"title" => "one"}},
               %{"headers" => %{"operation" => "insert"}, "value" => %{"title" => "two"}},
               %{"headers" => %{"operation" => "insert"}, "value" => %{"title" => "three"}}
             ] = Jason.decode!(resp.resp_body)
    end

    @tag table: {
           "todos",
           [
             "id int8 not null primary key generated always as identity",
             "title text",
             "completed boolean default false"
           ]
         }
    @tag data: {"todos", ["title"], [["one"], ["two"], ["three"]]}

    test "allows for specifying the table explicitly", _ctx do
      resp =
        Phoenix.ConnTest.build_conn()
        |> Phoenix.ConnTest.get("/shape/things-to-do", %{offset: "-1"})

      assert resp.status == 200
      assert Plug.Conn.get_resp_header(resp, "electric-offset") == ["0_0"]

      assert [
               %{"headers" => %{"operation" => "insert"}, "value" => %{"title" => "one"}},
               %{"headers" => %{"operation" => "insert"}, "value" => %{"title" => "two"}},
               %{"headers" => %{"operation" => "insert"}, "value" => %{"title" => "three"}}
             ] = Jason.decode!(resp.resp_body)
    end

    @tag table: {
           "ideas",
           [
             "id int8 not null primary key generated always as identity",
             "title text",
             "plausible boolean default false",
             "completed boolean default false"
           ]
         }
    @tag data: {
           "ideas",
           ["title", "plausible"],
           [["world peace", false], ["world war", true], ["make tea", true]]
         }

    test "allows for mixed definition using path and [where, column] modifiers", _ctx do
      resp =
        Phoenix.ConnTest.build_conn()
        |> Phoenix.ConnTest.get("/shape/ideas", %{offset: "-1"})

      assert resp.status == 200
      assert Plug.Conn.get_resp_header(resp, "electric-offset") == ["0_0"]

      assert [
               %{"headers" => %{"operation" => "insert"}, "value" => %{"title" => "world war"}},
               %{"headers" => %{"operation" => "insert"}, "value" => %{"title" => "make tea"}}
             ] = Jason.decode!(resp.resp_body)
    end

    @tag table: {
           {"food", "toeats"},
           [
             "id int8 not null primary key generated always as identity",
             "food text"
           ]
         }
    @tag data: {
           {"food", "toeats"},
           ["food"],
           [["peas"], ["beans"], ["sweetcorn"]]
         }

    test "can provide a custom namespace", _ctx do
      resp =
        Phoenix.ConnTest.build_conn()
        |> Phoenix.ConnTest.get("/shape/toeats", %{offset: "-1"})

      assert resp.status == 200
      assert Plug.Conn.get_resp_header(resp, "electric-offset") == ["0_0"]

      assert [
               %{"headers" => %{"operation" => "insert"}, "value" => %{"food" => "peas"}},
               %{"headers" => %{"operation" => "insert"}, "value" => %{"food" => "beans"}},
               %{"headers" => %{"operation" => "insert"}, "value" => %{"food" => "sweetcorn"}}
             ] = Jason.decode!(resp.resp_body)
    end

    @tag table: {
           "todos",
           [
             "id int8 not null primary key generated always as identity",
             "title text",
             "completed boolean default false"
           ]
         }
    @tag data: {
           "todos",
           ["title", "completed"],
           [["one", false], ["two", false], ["three", true]]
         }

    test "accepts Ecto queries as the shape definition", _ctx do
      resp =
        Phoenix.ConnTest.build_conn()
        |> Phoenix.ConnTest.get("/shape/query-where", %{offset: "-1"})

      assert resp.status == 200
      assert Plug.Conn.get_resp_header(resp, "electric-offset") == ["0_0"]

      assert [
               %{"headers" => %{"operation" => "insert"}, "value" => %{"title" => "one"}},
               %{"headers" => %{"operation" => "insert"}, "value" => %{"title" => "two"}}
             ] = Jason.decode!(resp.resp_body)

      resp =
        Phoenix.ConnTest.build_conn()
        |> Phoenix.ConnTest.get("/shape/query-bare", %{offset: "-1"})

      assert resp.status == 200
      assert Plug.Conn.get_resp_header(resp, "electric-offset") == ["0_0"]

      assert [
               %{"headers" => %{"operation" => "insert"}, "value" => %{"title" => "one"}},
               %{"headers" => %{"operation" => "insert"}, "value" => %{"title" => "two"}},
               %{"headers" => %{"operation" => "insert"}, "value" => %{"title" => "three"}}
             ] = Jason.decode!(resp.resp_body)

      resp =
        Phoenix.ConnTest.build_conn()
        |> Phoenix.ConnTest.get("/shape/query-config", %{offset: "-1"})

      assert resp.status == 200
      assert Plug.Conn.get_resp_header(resp, "electric-offset") == ["0_0"]

      assert [
               %{"headers" => %{"operation" => "insert"}, "value" => %{"title" => "one"}},
               %{"headers" => %{"operation" => "insert"}, "value" => %{"title" => "two"}},
               %{"headers" => %{"operation" => "insert"}, "value" => %{"title" => "three"}}
             ] = Jason.decode!(resp.resp_body)

      resp =
        Phoenix.ConnTest.build_conn()
        |> Phoenix.ConnTest.get("/shape/query-config2", %{offset: "-1"})

      assert resp.status == 200
      assert Plug.Conn.get_resp_header(resp, "electric-offset") == ["0_0"]

      assert [
               %{"headers" => %{"operation" => "insert"}, "value" => %{"title" => "one"}},
               %{"headers" => %{"operation" => "insert"}, "value" => %{"title" => "two"}},
               %{"headers" => %{"operation" => "insert"}, "value" => %{"title" => "three"}}
             ] = Jason.decode!(resp.resp_body)

      resp =
        Phoenix.ConnTest.build_conn()
        |> Phoenix.ConnTest.get("/shape/query-module", %{offset: "-1"})

      assert resp.status == 200
      assert Plug.Conn.get_resp_header(resp, "electric-offset") == ["0_0"]

      assert [
               %{"headers" => %{"operation" => "insert"}, "value" => %{"title" => "one"}},
               %{"headers" => %{"operation" => "insert"}, "value" => %{"title" => "two"}},
               %{"headers" => %{"operation" => "insert"}, "value" => %{"title" => "three"}}
             ] = Jason.decode!(resp.resp_body)
    end
  end

  describe "Plug.Router - shape/2" do
    @describetag wip: true
    @describetag table: {
                   "todos",
                   [
                     "id int8 not null primary key generated always as identity",
                     "title text",
                     "completed boolean default false",
                     "plausible boolean default false"
                   ]
                 }
    @describetag data:
                   {"todos", ["title", "plausible"],
                    [["one", true], ["two", true], ["three", true]]}

    defmodule MyScope do
      use Plug.Router
      use Electric.Phoenix.Router, opts_in_assign: :options

      plug :match
      plug :dispatch

      shape "/todos"
    end

    defmodule MyRouter do
      use Plug.Router, copy_opts_to_assign: :options
      use Electric.Phoenix.Router

      import Ecto.Query, only: [from: 2]

      plug :match
      plug :dispatch

      get "/" do
        send_resp(conn, 200, "hello")
      end

      shape "/shapes/todos"
      shape "/shapes/things-to-do", table: "todos"

      shape "/shapes/ideas",
        table: "todos",
        where: "plausible = true",
        columns: ["id", "title"],
        replica: :full,
        storage: %{compaction: :disabled}

      shape "/shapes/query-where", from(t in Support.Todo, where: t.completed == false)
      shape "/shapes/query-module", Support.Todo
      forward "/namespace", to: MyScope

      match _ do
        send_resp(conn, 404, "not found")
      end
    end

    setup(ctx) do
      opts = Shapes.Api.plug_opts(electric_opts(ctx))

      [plug_opts: [electric: opts]]
    end

    test "raises compile-time error if Plug.Router is not configured to copy_opts_to_assign" do
      assert_raise ArgumentError, fn ->
        Code.compile_string("""
        defmodule BreakingRouter do
          use Plug.Router
          use Electric.Phoenix.Router

          plug :match
          plug :dispatch

          shape "/shapes/todos"
        end
        """)
      end
    end

    test "doesn't raise compile time error if copy_opts_to_assign is set in the opts" do
      Code.compile_string("""
      defmodule WorkingRouter do
        use Plug.Router
        use Electric.Phoenix.Router, opts_in_assign: :options

        plug :match
        plug :dispatch

        shape "/todos"
      end
      """)
    end

    for path <-
          ~w(/shapes/todos /shapes/things-to-do /shapes/ideas /shapes/query-where /shapes/query-module /namespace/todos) do
      test "plug route #{path}", ctx do
        resp =
          conn(:get, unquote(path), %{"offset" => "-1"})
          |> MyRouter.call(ctx.plug_opts)

        assert resp.status == 200
        assert Plug.Conn.get_resp_header(resp, "electric-offset") == ["0_0"]

        assert [
                 %{"headers" => %{"operation" => "insert"}, "value" => %{"title" => "one"}},
                 %{"headers" => %{"operation" => "insert"}, "value" => %{"title" => "two"}},
                 %{"headers" => %{"operation" => "insert"}, "value" => %{"title" => "three"}}
               ] = Jason.decode!(resp.resp_body)
      end
    end
  end
end
