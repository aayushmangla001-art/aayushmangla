# aayushmangla — Roblox game scripts

This repo holds the game's scripts as plain files, synced into Roblox Studio with
[Rojo](https://rojo.space). Changes can be made here (by you or by Claude from any
device), then pulled into Studio and published whenever you're at your computer.

## Folder layout

| Folder         | Appears in Studio as                              | Use for                     |
|----------------|---------------------------------------------------|-----------------------------|
| `src/server/`  | `ServerScriptService`                             | Server scripts              |
| `src/client/`  | `StarterPlayer.StarterPlayerScripts`              | LocalScripts                |
| `src/shared/`  | `ReplicatedStorage`                               | ModuleScripts used by both  |

Files are synced directly into those services. Anything already in the place that
doesn't have a matching file (maps, models, GUIs, scripts not yet moved in) is left
alone. Don't edit a synced script inside Studio — Rojo overwrites it from the files.

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

## Game systems (added Oct 2026)

All prices, IDs, rewards and sounds are in **`src/shared/GameKit/Config.luau`**.

| System | Files |
|--------|-------|
| Loading screen | `src/first/LoadingScreen.client.luau` |
| Global leaderboards (money, playtime, wins) | `src/server/Leaderboards.server.luau` |
| Glass bridge revive (1st free, then Robux) | `src/server/BridgeRevive.server.luau`, `src/client/BridgeUI.client.luau` |
| Skip to End / Show Path / Kill All buttons | `src/server/BridgePowers.server.luau`, `src/client/BridgeUI.client.luau` |
| Troll menu + spectate | `src/server/Troll.server.luau`, `src/client/TrollUI.client.luau` |
| Invite friends, group and like rewards | `src/server/Rewards.server.luau`, `src/client/RewardsUI.client.luau` |
| Sound & visual effects | `src/client/Effects.client.luau`, `src/shared/GameKit/Sfx.luau`, `Vfx.luau` |
| Saved player stats / Robux purchases | `src/server/PlayerStats.luau`, `src/server/Purchases.luau` |

### Setup checklist

1. **Robux products** — Creator Dashboard → your game → Monetization → Developer
   Products. Make one for each entry in `Config.Products` (Revive 9 R$, Skip to End,
   Show Path, Kill All, Troll Kill/Fling/Push) and paste each ID into `Config.Products`.
   Until an ID is filled in, that button is free in Studio (for testing) and shows
   "Coming soon" in the real game.
2. **Group reward** — put your group's ID in `Config.Group.GroupId`.
3. **Leaderboards** — they appear next to the spawn automatically. To choose the spot,
   make a Folder in Workspace named `Leaderboards` with three anchored Parts named
   `MoneyBoard`, `PlaytimeBoard`, `WinsBoard` (the board shows on each part's Front face).
4. **Saving in Studio** — Home → Game Settings → Security → *Enable Studio Access to API
   Services*, if you want rewards and leaderboards to save while testing in Studio.
5. **Sounds** — `Config.Sounds` uses sounds built into Roblox. Swap any `Id` for
   `rbxassetid://...` from the Creator Store to change it; `Volume = 0` turns it off.

Robux purchases are all handled in `Purchases.luau` (Roblox allows only one handler).
Add new money packs to `MoneyShopConfig` as before; they are picked up automatically.
