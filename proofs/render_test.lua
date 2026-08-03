-- The proof that `prova init package` produces a *working* package in BOTH its shapes — standalone
-- (core + repo trappings, a repo-ready directory) and local (core only, under the owning package's
-- packages). Black-box throughout: render into a tempdir, inspect the tree, then drive the
-- rendered package's own `prova` and `prova package lint` exactly as its author would.
--
-- The local variant is exercised by supplying the same switch + answers `prova init` injects
-- (`prova:in-package`, `prova_package_root`, `prova_packages_dir`) — prova's own tests prove the
-- injection itself; this proof owns what the archetype DOES with it.
--
-- The nested run uses `$PROVA_BIN` if set (so a dev can pin the binary under test), else `prova` on
-- PATH — the version a real user would have installed.

local ARCHETYPE = prova.root -- this repo *is* the archetype under test
local PROVA = os.getenv("PROVA_BIN") or "prova"

local standalone = prova.fixture("standalone", Scope.File, function(ctx)
	return archetect.render({
		source = ARCHETYPE,
		answers = { name = "acme", description = "A test package" },
		defaults = true, -- org/author take their prompt defaults
		destination = ctx:tempdir(),
	})
end)

local localized = prova.fixture("localized", Scope.File, function(ctx)
	-- The destination stands in for an owning package's root; the switch + answers are exactly what
	-- `prova init` injects when the cwd is inside a package with a declared packages.
	return archetect.render({
		source = ARCHETYPE,
		answers = {
			name = "acme",
			description = "A test package",
			prova_package_root = ".",
			prova_packages_dir = ".prova/packages",
		},
		switches = { "prova:in-package" },
		destination = ctx:tempdir(),
	})
end)

-- Layout + no un-rendered `{{ }}` markers, via the declarative harness on the existing renders.
archetect.verify(standalone, {
	name = "package-standalone",
	expected_files = {
		"prova-acme/prova.toml",
		"prova-acme/init.lua",
		"prova-acme/library/acme.lua",
		"prova-acme/proofs/acme_test.lua",
		"prova-acme/README.md",
		"prova-acme/LICENSE",
		"prova-acme/.gitignore",
		"prova-acme/.version-line",
		"prova-acme/.github/workflows/test.yaml",
		"prova-acme/.github/workflows/release.yaml",
	},
})

archetect.verify(localized, {
	name = "package-local",
	expected_files = {
		".prova/packages/acme/prova.toml",
		".prova/packages/acme/init.lua",
		".prova/packages/acme/library/acme.lua",
		".prova/packages/acme/proofs/acme_test.lua",
		".prova/packages/acme/README.md",
	},
})

--- Run `cmd` in `dir` and return the completed shell result.
local function run_in(dir, cmd)
	return shell.run(cmd, { cwd = dir })
end

prova.describe("the standalone render", function()
	prova.test("keeps the repo trappings out of the core", function(t)
		local tree = t:use(standalone)
		local readme = tree:file("prova-acme/README.md"):read()
		t:expect(readme, "standalone README must carry the consumer pin"):contains("tag = \"v1\"")
	end)

	prova.test("self-test runs green and the package lints clean", function(t)
		local tree = t:use(standalone)
		local dir = tree:dir("prova-acme").path
		local r = run_in(dir, PROVA)
		t:expect(r.code, "prova exited non-zero:\n" .. r.stderr .. r.stdout):equals(0)
		local lint = run_in(dir, PROVA .. " package lint init.lua")
		t:expect(lint.code, "lint failed:\n" .. lint.stderr .. lint.stdout):equals(0)
	end)
end)

-- A per-test scratch dir for renders that are themselves the assertion (e.g. the error case).
local scratch = prova.fixture("scratch", Scope.Test, function(ctx)
	return { path = ctx:tempdir() }
end)

prova.describe("the local render", function()
	prova.test("carries no repo trappings", function(t)
		local tree = t:use(localized)
		t:expect(tree:file(".prova/packages/acme/LICENSE")):never():exists()
		t:expect(tree:file(".prova/packages/acme/.version-line")):never():exists()
		t:expect(tree:dir(".prova/packages/acme/.github")):never():exists()
		local readme = tree:file(".prova/packages/acme/README.md"):read()
		t:expect(readme, "local README must not sell a git pin"):never():contains("tag = \"v1\"")
	end)

	prova.test("self-test runs green in place", function(t)
		local tree = t:use(localized)
		local dir = tree:dir(".prova/packages/acme").path
		local r = run_in(dir, PROVA)
		t:expect(r.code, "prova exited non-zero:\n" .. r.stderr .. r.stdout):equals(0)
	end)

	prova.test("without a packages the render fails with guidance", function(t)
		local dest = t:use(scratch).path
		local ok, err = pcall(function()
			return archetect.render({
				source = ARCHETYPE,
				answers = { name = "acme", description = "A test package" },
				switches = { "prova:in-package" }, -- in a package, but no packages answer
				destination = dest,
			})
		end)
		t:expect(ok, "a local render without packages must error"):equals(false)
		t:expect(tostring(err)):contains("packages")
	end)
end)
