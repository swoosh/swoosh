defmodule MyApp.FakeView do
  use Swoosh.View, root: "test/support/fixtures/templates"
end

defmodule MyApp.FakeLayout do
  use Swoosh.View, root: "test/support/fixtures/templates/layout"
end
