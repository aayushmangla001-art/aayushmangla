# aayushmangla — Roblox game scripts

This repo holds the game's scripts as plain files, synced into Roblox Studio with
[Rojo](https://rojo.space). Changes can be made here (by you or by Claude from any
device), then pulled into Studio and published whenever you're at your computer.

## Folder layout

| Folder         | Appears in Studio as                              | Use for                     |
|----------------|---------------------------------------------------|-----------------------------|
| `src/server/`  | `ServerScriptService.Server`                      | Server scripts              |
| `src/client/`  | `StarterPlayer.StarterPlayerScripts.Client`       | LocalScripts                |
| `src/shared/`  | `ReplicatedStorage.Shared`                        | ModuleScripts used by both  |

Only these three folders are managed by Rojo. Everything else in your place (maps,
models, parts, GUIs built in Studio, other scripts) is left alone.

### File naming → script type

| File name               | Becomes        |
|-------------------------|----------------|
| `Name.server.luau`      | `Script`       |
| `Name.client.luau`      | `LocalScript`  |
| `Name.luau`             | `ModuleScript` |
| a folder                | `Folder`       |
| `init.server.luau` etc. | makes the folder itself that script, with the other files as its children |

## One-time setup (on your laptop)

1. **Install Rokit** (tool manager): see https://github.com/rojo-rbx/rokit#installation
2. **Clone this repo** and install Rojo:
   ```sh
   git clone https://github.com/aayushmangla001-art/aayushmangla.git
   cd aayushmangla
   rokit install
   ```
3. **Install the Rojo Studio plugin**: run `rojo plugin install`, or get it from the
   Roblox Creator Store ("Rojo").
4. **Move your existing scripts into the repo**: for each script in your game, create a
   file in the matching `src/` folder (using the naming rules above) and paste the script's
   code into it. Then delete the original from Studio so you don't have duplicates.
   Commit and push.
5. You can delete the example `Hello` / `main` files once you have your own.

## Everyday workflow

1. Ask for changes (e.g. via Claude) — they get committed and pushed to this repo.
2. When you're at your laptop:
   ```sh
   git pull
   rojo serve
   ```
3. In Studio, open your place, open the **Rojo** plugin and click **Connect**.
   The scripts update live.
4. Playtest, then **File → Publish to Roblox**.

> Tip: while connected, edit scripts in this folder (e.g. with VS Code), not inside
> Studio — Rojo syncs files → Studio, and Studio edits to synced scripts get overwritten.
