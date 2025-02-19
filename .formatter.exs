locals_without_parens = [
  # Electric.Phoenix.Router
  shape: 1,
  shape: 2
]

[
  locals_without_parens: locals_without_parens,
  export: [locals_without_parens: locals_without_parens],
  import_deps: [:plug, :phoenix, :ecto],
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"]
]
