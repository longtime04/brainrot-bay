# Brainrot Bay: Grab & Dash

An entry for make.fun's "Make the best AI Roblox brainrot game" bounty (roblox-brainrot-01): a 3D
Steal-a-Brainrot-style game on a sunny island, built entirely from code — no hand-modelled place.

## The game

Brainrots — absurd meme characters like Noodle Newt, Disco Dumpling and The Last Wi-Fi Router — spawn on
glowing pads along a beach lane. Grab one, carry it home on your head, and place it on a pad at your base:
it earns cash every second at its labelled rate, and rarer brainrots (Epic, Legendary, Mythic, Secret)
earn far more. Mutations make some spawns Gold (x2), Diamond (x4) or Rainbow (x10).

Watch out:

- **The tsunami.** Every 100 seconds a wave sweeps the island. Anyone caught outside a raised base plot
  is washed away and drops what they carry.
- **Thieves.** Your base shield locks for 60 seconds after you place a brainrot or press Lock; while it
  is down, rivals can steal your placed brainrots and run them home.
- **Rebirth.** Trade all your cash and placed brainrots for a permanent income multiplier, and spend
  cash on Boots that make you run faster.

Progress (cash, rebirths, boots level, placed brainrots) is saved in a DataStore and restored on rejoin.

## How to play

1. Walk the beach lane and press the prompt on a brainrot to **Grab** it.
2. Run it back to your base (the plot with your name on the sign) and use a pad's **Place** prompt.
3. Your placed brainrots pay out every second — watch the `+$N` float over your base.
4. When the tsunami warning sounds, stand on any base plot until it passes.
5. Spend cash on **Boots** and **Rebirth** with the buttons at the bottom-right.

## How it is built

A Rojo project: `default.project.json` lays out the services, and `src/` holds all the code.

- `src/shared/BrainrotData.luau` — the cast table: rarities, spawn odds, mutations and income math.
- `src/server/WorldBuilder.luau` — builds the island, the 8 base plots, the beach lane, decorations
  and every brainrot character model (`buildBrainrotModel`) from parts at server start.
- `src/server/BrainrotSpawner.luau` — the spawn loop, grab prompts, carrying and despawning.
- `src/server/BaseManager.luau` — plot claims, placement, the income tick and floating earnings text.
- `src/server/TsunamiController.luau` — the warning, the wave sweep and wash-aways.
- `src/server/StealService.luau` — shield timers, the Lock button and stealing.
- `src/server/PlayerDataService.luau` — leaderstats, the DataStore, rebirth and the boots shop.
- `src/client/Game.client.luau` — the HUD: cash and income, banners, shop buttons, earnings popups.

`main.ts` (Node 22, standard library only) hands the game in: it copies `game.rbxl`, `src/`,
`screenshots/` and `PLAY.json` to `/output` (leaving out every name that starts with a dot, which would
fail the entry) and writes `/output/dossier.json` with `vendor/makefun-roblox.ts`, the kit's copy,
unchanged.

## Build and hand in

    rojo build default.project.json --output game.rbxl
    mkdir -p out && MAKEFUN_OUTPUT_DIR=out node main.ts
