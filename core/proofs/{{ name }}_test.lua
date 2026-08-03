-- Self-test for prova-{{ name }}. `require("{{ name }}")` resolves to THIS package — prova.toml
-- declares it as a path package at "." — so the suite proves the package exactly the way a consumer
-- uses it. Hermetic by default (no docker, no network): the bar the package must always clear.
--
-- As you grow the package, gate the tests that touch a real resource with `{ requires = { "docker" } }`
-- (or the tool your topology needs), so they skip cleanly where it's absent instead of failing.
local {{ ident }} = require("{{ name }}")

prova.test("greets by name", function(t)
  t:expect({{ ident }}.greet("world")):equals("hello, world")
end)
