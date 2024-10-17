defmodule Electric.Phoenix.GatewayTest do
  use ExUnit.Case, async: true
  use Plug.Test

  alias Electric.Phoenix.Gateway

  require Phoenix.ConnTest

  @endpoint Electric.Phoenix.LiveViewTest.Endpoint

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

    forward "/shapes/items",
      to: Gateway.Plug,
      shape: Electric.Client.shape!("items"),
      client: MyEnv.client!()

    forward "/shapes/reasons",
      to: Gateway.Plug,
      client: MyEnv.client!(),
      assigns: %{shape: Electric.Client.shape!("reasons", where: "valid = true")}
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
