defmodule Electric.Phoenix.GatewayTest do
  use ExUnit.Case, async: true
  use Plug.Test

  alias Electric.Phoenix.Gateway

  require Phoenix.ConnTest

  @endpoint Electric.Phoenix.LiveViewTest.Endpoint

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
  end

  defmodule MyEnv.TestRouter do
    use Plug.Router

    plug :match
    plug :dispatch

    import Ecto.Query

    Code.ensure_loaded(Support.User)

    forward "/shapes/items",
      to: Gateway.Plug,
      shape: Electric.Client.shape!("items"),
      client: MyEnv.client!()

    forward "/shapes/users-ecto",
      to: Gateway.Plug,
      shape: Support.User,
      client: MyEnv.client!()

    forward "/shapes/users-query",
      to: Gateway.Plug,
      shape: from(u in Support.User, where: u.visible == true),
      client: MyEnv.client!()

    forward "/shapes/reasons",
      to: Gateway.Plug,
      client: MyEnv.client!(),
      assigns: %{shape: Electric.Client.shape!("reasons", where: "valid = true")}

    forward "/shapes/users/:user_id/:age",
      to: Gateway.Plug,
      shape:
        Electric.Phoenix.Gateway.shape!(
          from(u in Support.User, where: u.visible == true),
          id: :user_id,
          age: [>: :age]
        ),
      client: MyEnv.client!()

    forward "/shapes/keyword/:user_id/:age",
      to: Gateway.Plug,
      shape: [
        from(u in Support.User, where: u.visible == true),
        id: :user_id,
        age: [>: :age]
      ],
      client: MyEnv.client!()

    forward "/shapes/atom/:visible",
      to: Gateway.Plug,
      shape: [Support.User, :visible],
      client: MyEnv.client!()

    get "/shapes/dynamic/:user_id/:age" do
      shape =
        Support.User
        |> where(visible: ^conn.params["visible"], id: ^conn.params["user_id"])
        |> where([u], u.age > ^conn.params["age"])

      Electric.Phoenix.Gateway.send_configuration(conn, shape, MyEnv.client!())
    end
  end

  describe "Plug" do
    test "returns a url and query parameters" do
      resp =
        conn(:get, "/things", %{"table" => "things"})
        |> Gateway.Plug.call(%{client: MyEnv.client!()})

      assert {200, _headers, body} = sent_resp(resp)

      assert %{
               "url" => "https://cloud.electric-sql.com/v1/shape/things",
               "headers" => %{"electric-mock-auth" => hash}
             } = Jason.decode!(body)

      assert is_binary(hash)
    end

    test "includes where clauses in returned parameters" do
      resp =
        conn(:get, "/things", %{"table" => "things", "where" => "colour = 'blue'"})
        |> Gateway.Plug.call(%{client: MyEnv.client!()})

      assert {200, _headers, body} = sent_resp(resp)

      assert %{
               "url" => "https://cloud.electric-sql.com/v1/shape/things",
               "where" => "colour = 'blue'",
               "headers" => %{"electric-mock-auth" => hash}
             } = Jason.decode!(body)

      assert is_binary(hash)
    end

    test "allows for preconfiguring the shape" do
      resp =
        conn(:get, "/shapes/items", %{})
        |> MyEnv.TestRouter.call([])

      assert {200, _headers, body} = sent_resp(resp)

      assert %{
               "url" => "https://cloud.electric-sql.com/v1/shape/items",
               "headers" => %{"electric-mock-auth" => _hash}
             } = Jason.decode!(body)
    end

    test "allows for preconfiguring the shape via assigns" do
      resp =
        conn(:get, "/shapes/reasons", %{})
        |> MyEnv.TestRouter.call([])

      assert {200, _headers, body} = sent_resp(resp)

      assert %{
               "url" => "https://cloud.electric-sql.com/v1/shape/reasons",
               "where" => "valid = true",
               "headers" => %{"electric-mock-auth" => _hash}
             } = Jason.decode!(body)
    end

    test "allows for defining the shape with an ecto struct" do
      resp =
        conn(:get, "/shapes/users-ecto", %{})
        |> MyEnv.TestRouter.call([])

      assert {200, _headers, body} = sent_resp(resp)

      assert %{
               "url" => "https://cloud.electric-sql.com/v1/shape/users",
               "headers" => %{"electric-mock-auth" => _hash}
             } = Jason.decode!(body)
    end

    test "allows for defining the shape with an ecto query" do
      resp =
        conn(:get, "/shapes/users-query", %{})
        |> MyEnv.TestRouter.call([])

      assert {200, _headers, body} = sent_resp(resp)

      assert %{
               "url" => "https://cloud.electric-sql.com/v1/shape/users",
               "where" => ~s[("visible" = TRUE)],
               "headers" => %{"electric-mock-auth" => _hash}
             } = Jason.decode!(body)
    end

    test "allows for defining a shape using path parameters" do
      resp =
        conn(:get, "/shapes/users/b9d228a6-307e-442f-bee7-730a8b66ab5a/32", %{"visible" => true})
        |> MyEnv.TestRouter.call([])

      assert {200, _headers, body} = sent_resp(resp)

      assert %{
               "url" => "https://cloud.electric-sql.com/v1/shape/users",
               "where" =>
                 ~s[("visible" = TRUE) AND ("id" = 'b9d228a6-307e-442f-bee7-730a8b66ab5a') AND ("age" > 32)],
               "headers" => %{"electric-mock-auth" => _hash}
             } = Jason.decode!(body)

      # TODO: tests for where clause gen
    end

    test "raises if parameter will not cast to column type" do
      assert_raise Plug.Conn.WrapperError, fn ->
        conn(:get, "/shapes/users/--;%20delete%20from%20users/32", %{"visible" => true})
        |> MyEnv.TestRouter.call([])
      end
    end

    test "allows for defining a dynamic shape with a keyword list" do
      resp =
        conn(:get, "/shapes/keyword/b9d228a6-307e-442f-bee7-730a8b66ab5a/32", %{"visible" => true})
        |> MyEnv.TestRouter.call([])

      assert {200, _headers, body} = sent_resp(resp)

      assert %{
               "url" => "https://cloud.electric-sql.com/v1/shape/users",
               "where" =>
                 ~s[("visible" = TRUE) AND ("id" = 'b9d228a6-307e-442f-bee7-730a8b66ab5a') AND ("age" > 32)],
               "headers" => %{"electric-mock-auth" => _hash}
             } = Jason.decode!(body)
    end

    test "allows for defining a dynamic shape when column and parameter name are the same" do
      resp =
        conn(:get, "/shapes/atom/true", %{})
        |> MyEnv.TestRouter.call([])

      assert {200, _headers, body} = sent_resp(resp)

      assert %{
               "url" => "https://cloud.electric-sql.com/v1/shape/users",
               "where" => ~s[("visible" = TRUE)],
               "headers" => %{"electric-mock-auth" => _hash}
             } = Jason.decode!(body)
    end

    test "send_configuration/3" do
      resp =
        conn(:get, "/shapes/dynamic/b9d228a6-307e-442f-bee7-730a8b66ab5a/44", %{
          "visible" => false
        })
        |> MyEnv.TestRouter.call([])

      assert {200, _headers, body} = sent_resp(resp)

      assert %{
               "url" => "https://cloud.electric-sql.com/v1/shape/users",
               "where" =>
                 ~s[(("visible" = FALSE) AND ("id" = 'b9d228a6-307e-442f-bee7-730a8b66ab5a')) AND ("age" > 44)],
               "headers" => %{"electric-mock-auth" => _hash}
             } = Jason.decode!(body)
    end

    test "works with Phoenix.Router.forward/3" do
      resp =
        Phoenix.ConnTest.build_conn()
        |> Phoenix.ConnTest.get("/shape/items")

      assert Phoenix.ConnTest.json_response(resp, 200) == %{
               "headers" => %{},
               "url" => "http://localhost:3000/v1/shape/items",
               "where" => "visible = true"
             }
    end

    test "works with Phoenix.Router.forward/3 and paramter based shapes" do
      resp =
        Phoenix.ConnTest.build_conn()
        |> Phoenix.ConnTest.get("/shape/generic", %{
          "table" => "clothes",
          "where" => "colour = 'red'"
        })

      assert Phoenix.ConnTest.json_response(resp, 200) == %{
               "headers" => %{},
               "url" => "http://localhost:3000/v1/shape/clothes",
               "where" => "colour = 'red'"
             }
    end
  end
end