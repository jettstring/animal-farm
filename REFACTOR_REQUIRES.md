# Refactor: Require Paths + Naming Convention Migration

You are refactoring a Roblox Luau game (project "Animal Farm") that was just migrated
to **Rojo** with a **feature-based** folder structure. The code moved locations and
the naming convention is changing. Your job is a **mechanical rename + repath refactor**.
**Do not change any game logic.**

---

## Ground rules (read first)

- Work only on the current `rojo` git branch. Do not touch `main`.
- **`default.project.json` and `sourcemap.json` are GENERATED — never hand-edit them.**
  `default.project.json` comes from `tools/genFeatureTree.js`; `sourcemap.json` comes
  from `rojo sourcemap`.
- **`sourcemap.json` is the source of truth for every instance path.** Whenever you need
  the correct require path for a module, find that module's node in `sourcemap.json` and
  read its instance path. Do not guess paths from memory.
- Before verifying, make sure the sourcemap is current. If unsure, run:
  `rojo sourcemap default.project.json -o sourcemap.json`
- This is a rename/repath refactor ONLY. Preserve all behavior. Do not restructure logic,
  change function bodies (except identifiers being renamed), or "improve" anything.
- Some files may ALREADY be renamed/repathed (the migration is partly done). For every
  rule below, **skip items already in the new form; only fix ones still in the old form.**
- Roblox instances that live only in Studio — `ReplicatedStorage.Assets`,
  `ReplicatedStorage.Remotes`, models, VFX — are **not** in the sourcemap and are **not**
  being renamed. Leave those raw references exactly as they are.
- Do not rename anything under `Packages` (Wally/third-party). `ReplicatedStorage.Packages.*`
  requires stay unchanged.

---

## Step 1 — Discover the current state

1. Read `default.project.json` and `sourcemap.json` to learn the DataModel layout.
2. Enumerate every `.luau` file under `src/`. For each, record its instance path from
   `sourcemap.json` (e.g. `ServerScriptService.Features.Base.Classes.BaseServer`).
3. Grep the whole `src/` tree for:
   - all `require(` calls
   - all cross-module type references (e.g. `SomeModule.SomeType`)
   - the old path fragments listed in Step 3 (to build your worklist)
4. Produce a short plan listing which files need edits before changing anything.

---

## Step 2 — Apply the naming convention

Rename each module's **file, its module table variable, its type(s), its `self`
annotations, its `return`, and every reference to it in other files.** A rename is not
done until every reference and every type usage is updated and resolves.

### Mapping

| Kind | Old name pattern | New name pattern | Examples |
|---|---|---|---|
| Server class module | `<Name>` | `<Name>Server` | `Base`→`BaseServer`, `Floor`→`FloorServer`, `RollStand`→`RollStandServer`, `AnimalStand`→`AnimalStandServer` |
| Server service | `<Name>Service` | `<Name>ServiceServer` | `BaseService`→`BaseServiceServer`, `AnimalService`→`AnimalServiceServer`, `DataService`→`DataServiceServer`, `NotificationService`→`NotificationServiceServer` |
| Client controller | `<Name>Controller` | `<Name>ServiceClient` | `BaseController`→`BaseServiceClient`, `CarryController`→`CarryServiceClient`, `InteractionController`→`InteractionServiceClient`, `NotificationController`→`NotificationServiceClient` |
| Shared util | `<Name>Util` | `<Name>ServiceUtil` | `BaseUtil`→`BaseServiceUtil`, `AnimalUtil`→`AnimalServiceUtil` |

### For each renamed module, update ALL of these

Using `Base` → `BaseServer` as the worked example:

- File name: `Base.luau` → `BaseServer.luau` (if not already).
- Module table: `local Base = {}` → `local BaseServer = {}`.
- Metatable line: `Base.__index = Base` → `BaseServer.__index = BaseServer`.
- Type declarations: `type Base = ...`, `export type Base = ...`,
  `type Base = typeof(setmetatable(...))` → all become `BaseServer`.
- Every method definition: `function Base.foo(self: Base, ...)` →
  `function BaseServer.foo(self: BaseServer, ...)`.
- Constructor return annotations: `function Base.new(...): Base` → `: BaseServer`.
- Any local casts / `& {}` intersections: keep the pattern, rename the symbol
  (e.g. `export type BaseServer = typeof(BaseServer) & { ... }` and
  `return BaseServer :: BaseServer` if that idiom is present).
- Bottom of file: `return Base` → `return BaseServer`.
- **In every other file that uses it:** the require variable name
  (`local Base = require(...)` → `local BaseServer = require(...)`) and every type
  reference (`Base.Base` → `BaseServer.BaseServer`, `: Base` → `: BaseServer`, etc.).

Apply the same treatment to the service, controller, and util renames.

---

## Step 3 — Rewrite require paths

Replace every stale require path with the module's **current instance path taken from
`sourcemap.json`.** The patterns below show the shape of the change, but always confirm
the exact target against the sourcemap — bucket names (`Source`, `Features`, `Game`,
`Core`, etc.) come from the generated tree, not from this document.

Old → new shape (confirm each against sourcemap.json):

- `ServerScriptService.ServerMain.Services.<Service>`
  → `ServerScriptService.Features.<Feature>.<ServiceServer>`
- `ServerScriptService.Classes.Base.<Class>`
  → `ServerScriptService.Features.Base.Classes.<ClassServer>`
- `ReplicatedStorage.Modules.<Module>`
  → `ReplicatedStorage.Source.<Game|Features/...>.<Module>`
- `ReplicatedStorage.Utils.<Util>`
  → `ReplicatedStorage.Source.Features.<Feature>.<UtilServiceUtil>`
- `ReplicatedStorage.Packages.<Pkg>` → **unchanged**

Also update the bootstrap scripts (`src/startup/Server.server.luau`,
`src/startup/Client.client.luau`): their require lists and any `Init`/`Start` references
must point at the new service names and paths.

Leave untouched: `ReplicatedStorage.Assets.*`, `ReplicatedStorage.Remotes.*`, and any
`WaitForChild`/raw references to Studio-only instances.

---

## Step 4 — Verify (must all pass)

1. Regenerate the sourcemap: `rojo sourcemap default.project.json -o sourcemap.json`.
2. Grep for leftover old fragments — there should be **zero** matches:
   `ServerMain`, `.Classes.Base`, `ReplicatedStorage.Modules`, `ReplicatedStorage.Utils`,
   and each old module name (`require(...).Base`, `\bBaseController\b`, `\bBaseUtil\b`, etc.).
3. Confirm every `require(` target exists as a node in `sourcemap.json` (no unresolved
   paths). If the repo has a Luau checker available (luau-lsp analyze, or `selene`), run it
   and confirm the refactor introduced no "unknown require" or "unknown type" errors.
4. If Studio + Rojo are available, sync and playtest the full loop: roll → buy → place →
   collect egg → sell. Behavior must be identical to before.

---

## Step 5 — Report and commit

- Summarize: files renamed, count of require paths rewritten, anything ambiguous you had
  to decide, and anything you could NOT resolve (flag these — do not guess).
- If everything resolves and playtests clean:
  `git add -A && git commit -m "Rewrite requires and apply feature naming convention"`
- Do not merge to `main`.

---

## If something is ambiguous

If a module's new location or new name is unclear (for example a util that could belong to
either a feature or `Core`, or a file whose feature is not obvious), **stop and ask** rather
than guessing. A wrong path silently breaks resolution and a wrong rename cascades across
files. List the ambiguous cases in your report.
