<p align="center">
  <a href="https://electric-sql.com" target="_blank">
    <picture>
      <source media="(prefers-color-scheme: dark)"
          srcset="https://raw.githubusercontent.com/electric-sql/meta/main/identity/ElectricSQL-logo-next.svg"
      />
      <source media="(prefers-color-scheme: light)"
          srcset="https://raw.githubusercontent.com/electric-sql/meta/main/identity/ElectricSQL-logo-black.svg"
      />
      <img alt="ElectricSQL logo"
          src="https://raw.githubusercontent.com/electric-sql/meta/main/identity/ElectricSQL-logo-black.svg"
      />
    </picture>
  </a>
</p>

# Electric.Phoenix

> [!CAUTION]
>
> ## Deprecated
>
> Integration between [Electric](https://electric-sql.com) and [Phoenix
> applications](https://www.phoenixframework.org/) is now done via
> [`Phoenix.Sync`](https://hexdocs.pm/phoenix_sync).

An adapter to integrate [Electric SQL's sync engine](https://electric-sql.com)
into [Phoenix web applications](https://www.phoenixframework.org/).

Documentation available at <https://hexdocs.pm/electric_phoenix/>.

## Installation

Install by adding `electric_phoenix` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:electric_phoenix, "~> 0.1.0"}
  ]
end
```
