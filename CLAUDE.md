# SimpleSequence

## Project
- GSE-style spell sequencer for WoW Forever (Camelot, Interface 16001, retail-based client with Midnight secret values). Plain Lua and XML, no libraries.
- `UI/Theme.lua` is a private copy of LibRefactorTheme-1.0 from the Refactor addon.
- Public repo: github.com/ProfetGit/SimpleSequence.

## Commands (run from the repo root)
- Specs, using busted from Refactor's toolchain:
  ```
  T=../../../../_retail_/Interface/AddOns/Refactor/.tools; lua5.1 -e "package.path=[[$T/share/lua/5.1/?.lua;$T/share/lua/5.1/?/init.lua;]]..package.path;package.cpath=[[$T/lib/lua/5.1/?.so;]]..package.cpath" "$T/lib/luarocks/rocks-5.1/busted/2.3.0-1/bin/busted" Tests/spec
  ```
- Single spec: replace `Tests/spec` with a file, e.g. `Tests/spec/compiler_spec.lua`.
- Headless load harness: `lua5.1 Tests/harness/run.lua` must end with `HARNESS OK` (0 errors, 0 missing globals).
- Syntax: `luac5.1 -p Core/*.lua UI/*.lua`.
- Lint: the `wow_lua_lint` MCP (flavor `forever`) only accepts files inside `_retail_/Interface/AddOns/`. Copy changed files to `_retail_/Interface/AddOns/_SSLintTmp/`, lint each file path (not the folder), then delete the folder.

## Verify
- Run specs, harness and lint before every commit.
- Known lint noise: StaticPopup_Show, RegisterStateDriver and SecureHandlerWrapScript flagged unknown; SetAttribute combat warnings in Engine.lua (guarded and queued); print-left-in in /seq help.
- Only testable in game: secure presses, macros, cast sequences, sounds, layout. Ask the user to test; `/seq demo` and `/seq debug` help.

## Architecture
- `SimpleSequence.toc`: load order; every new file must be listed there.
- `Core/Namespace.lua`: the `SS` table, event bus (`SS:On`/`SS:Fire`), constants (MAX_STEPS etc.).
- `Core/Database.lua`: SavedVariables `SimpleSequenceDB` and sanitisers; every change goes through `Update` (undo stack).
- `Core/Compiler.lua`: pure; turns a sequence into macro text per press (opener, loop, every-press lines).
- `Core/Builder.lua`: pure fight simulation behind "Build for me" (priority list → opener, loop, every press).
- `Core/Engine.lua`: secure buttons; a WrapScript snippet swaps the macro text on each press; state drivers handle resets.
- `Core/Bindings.lua`: override key bindings, per-character action-bar macros, SetMacroSpell icon feedback.
- `Core/Settings.lua` + `Core/ErrorSounds.lua`: Options menu items and error silencing.
- `UI/`: Window (3 columns), SequenceList, Editor, SpellSidebar, StepPopover, BuilderPanel, NextUp, Minimap, ShareDialog, DragDrop, Widgets, Theme.
- `Tests/spec/helpers/env.lua` stubs the API for specs; `Tests/harness/fakewow.lua` is the fake client.

## Conventions
- Use theme tokens (`Theme.colors.*`), never colour literals. Use the red `Theme:Button` only for write actions.
- Store spell IDs, never spell names.
- Check every game API with `wow_api_search` (flavor `forever`) before using it. The MCP's UI source is retail (mainline); Forever's isn't synced.
- Bump `## Version` in the TOC with each feature or fix commit. Message: `feat: SimpleSequence X.Y.Z, <summary>` plus bullet points.

## Gotchas (Forever client)
- Only the first global-cooldown `/cast` in a press tries to cast; later global-cooldown lines are skipped. Never put global-cooldown spells in Every press.
- Off-global-cooldown lines before the main cast still pass through.
- `/castsequence` only advances on a successful cast, and `QueryCastSequence(seq)` returns its current position. The mash-safe loops depend on both.
- `SetScript("OnKeyDown")` turns keyboard input back on: call `EnableKeyboard(false)` after it.
- The native Slider thumb drag runs backwards: `Widgets:Scroll` drives the thumb itself, so keep `slider:EnableMouse(false)`.
- The client plays error sounds (fizzles, spoken errors) itself, not UIErrorsFrame. Silence them with `MuteSoundFile` (`Core/ErrorSounds.lua`; IDs come from the wowdev community listfile cached at `~/.cache/hated-wow-mcp/.cache/community-listfile.csv`).
- Secret values: read cooldowns and tooltips out of combat only, and guard with `issecretvalue`.
- `SetMacroSpell` in combat is untested; Bindings turns it off after ADDON_ACTION_BLOCKED.
- Media TGAs are 32-bit, uncompressed, bottom-up origin (same header as the originals). WoW loads new art only on a game restart, not `/reload`.
- Harness: unknown frame methods return placeholder objects (this inflates frame counts). Read optional globals with `rawget(_G, name)`, or they count as missing.
- The game runs from `_forever_`; `_classic_beta_/Interface/AddOns/SimpleSequence` is a symlink to this folder.
