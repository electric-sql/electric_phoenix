defmodule Electric.Phoenix.ComponentTest do
  use ExUnit.Case, async: true

  Code.ensure_loaded(Support.User)

  require Ecto.Query
  require Phoenix.LiveViewTest

  import Phoenix.Component

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

  test "generates a script tag with the right configuration" do
    shape = Ecto.Query.where(Support.User, visible: true)

    html =
      Phoenix.LiveViewTest.render_component(
        &Electric.Phoenix.electric_client_configuration/1,
        shape: shape,
        client: client!(),
        key: "visible_user_config"
      )

    assert html =~ ~r/window\.visible_user_config = \{/
    assert html =~ ~r["url":"https://cloud.electric-sql.com/v1/shape/users"]
    assert html =~ ~r|"electric-mock-auth":"[a-z0-9]+"|
    assert html =~ ~r|"where":"\(\\"visible\\" = TRUE\)"|
  end

  test "allows for overriding how the configuration is used" do
    assigns = %{}

    html =
      Phoenix.LiveViewTest.rendered_to_string(~H"""
        <div>
          <Electric.Phoenix.electric_client_configuration client={client!()} shape={Ecto.Query.where(Support.User, visible: true)}>
            <:script :let={configuration}>
              root.render(React.createElement(MyApp, { client_config: <%= configuration %> }, null))
            </:script>
          </Electric.Phoenix.electric_client_configuration> 
        </div>
      """)

    assert html =~ ~r/React\.createElement.+client_config: \{/
    assert html =~ ~r["url":"https://cloud.electric-sql.com/v1/shape/users"]
    assert html =~ ~r|"electric-mock-auth":"[a-z0-9]+"|
    assert html =~ ~r|"where":"\(\\"visible\\" = TRUE\)"|
  end
end
