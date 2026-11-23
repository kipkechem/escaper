# Escaper

A physics-puzzle escape room for Roblox. The puzzles take after Human Fall Flat: real weight,
counterweights, levers, things you can carry and stack, more than one solution, and no
on-screen instructions beyond stencilled weights and signs. The character is a normal Roblox
avatar that can grab, carry, drag, turn and throw objects.

The game is a **tower of 100 floors**. Each level is a floor, and the floors belong to
overlapping staircases:
- the very hard **main stair**
- **easy (E)**, **medium (M)** and **hard (H)** staircases beside it

Some levels have several solutions, each leading onto a different staircase. Every staircase
rejoins the main stair before Level 100. The rules and layout are in
[docs/TOWER.md](docs/TOWER.md), and the full map is in [docs/TOWER_MAP.md](docs/TOWER_MAP.md).

**Status:** the core systems and all 277 levels of the map exist as code and data. Two levels
are built as grey-box rooms (plain shapes, no art or sound yet):
- Level 1, *The Loading Dock* (the tutorial)
- Level 2, *The Switchboard* (the first fork)

The exits that lead past them end at "under construction" pads. Neither level has been
playtested in Roblox Studio yet; see [What to playtest](#what-to-playtest).

## Open it in Roblox Studio

You need [Rokit](https://github.com/rojo-rbx/rokit) (installs the tools at the versions in
`rokit.toml`) and Roblox Studio.

```sh
rokit install
mkdir -p build
rojo build -o build/escaper.rbxl
lune run tools/bake.luau build/escaper.rbxl   # optional: puts the tower into the file
```

Open `build/escaper.rbxl` in Studio and press **Play** (F5). To test co-op, use the
**Test** tab: choose 2 players and **Start** (local server).

`tools/bake.luau` runs the builders ahead of time, so the levels and the connectors between
them are visible in Studio's edit mode and you can move things by hand. Without it, the
server builds them when it starts. Either way, the server only builds what is missing from
`Workspace.Rooms` and `Workspace.Tower`.

**Live editing with `rojo serve`:** run `rojo serve`, open the built place (not a new
Baseplate template: its baseplate cuts through the truck bay and the lift pit) and connect
with the Rojo Studio plugin. Code changes then sync while you work.

## Controls

| Action | Keyboard and mouse | Gamepad | Touch |
| --- | --- | --- | --- |
| Grab / drop | Click or **Q** | **R2** | **Grab** button |
| Throw | **F** | **R1** | **Throw** button |
| Turn held object 90° | **R** | **Y** | **Turn** button |
| Levers, reset consoles | **E** (hold for reset) | **X** | tap the prompt |

With a mouse you aim with the pointer. Touch, gamepad and shift-lock aim at the centre dot.
If nothing grabbable is under your aim, the nearest one in front of you within reach is
picked. Crates straighten up when you pick them up, so they stack flat.

## How it plays

- **Weight is real.** Crates have a mass, shown on them. You can lift up to 45 KG; heavier
  things can only be dragged, and carrying slows you down.
- **Plates and lifts weigh what rests on them,** including stacked crates and players
  standing on crates. A player counts as 25 KG plus what they carry.
- **You cannot stand on what you are holding,** so no carrying yourself up a wall.
- **Doors stop rather than crush,** so a crate can prop one open.

Walkthroughs, numbers and alternative solutions: [Level 1](docs/ROOM_1.md),
[Level 2](docs/LEVEL_2.md).

## Building puzzles in Studio

Every puzzle piece is a **tag** plus a few **attributes** on a part or model, so new rooms
can be built in Studio without code. Add tags in the Properties window (Tags section) and
attributes under Attributes. Wiring works by name: a plate's `Output` turns a signal on,
and a door's `Input` listens for it.

| Tag | Put it on | Attributes |
| --- | --- | --- |
| `Room` | a model holding one room | `RoomName`. Signal names are local to their room. |
| `Grabbable` | an unanchored part, or a model of welded parts | `Mass` (sets the weight), `DisplayName`, `Key` (for sockets) |
| `PressurePlate` | an anchored part (its top face) | `Output`, `RequiredMass`, `Label`, `SensorHeight` (14), `ShowGauge` (true) |
| `Socket` | a non-colliding, non-query part above a tray | `Key` (matches a grabbable's `Key`, e.g. `Fuse`), `Output` |
| `Lever` | a model with an anchored `Handle` part (optional `Base`, `Lamp`) | `Output`, `Mode` (`Toggle` or `Timed`), `Duration`, `Label` |
| `Door` | an anchored part or model (also gates, bridges, ladders) | `Input`, `OpenOffset` (default: up by its height), `OpenTime`, `Latch` |
| `Indicator` | a part that lights green | `Input` |
| `CounterweightLift` | a model with parts `PlatformA` (at its top) and `PlatformB` (at its bottom) | `Travel`, `Speed`, `TareA`, `TareB`, `Deadband`, `Output` (on when B is up), `LabelA`, `LabelB` |
| `Checkpoint` | a trigger part, or the SpawnLocation | `Order` (floor × 10 + n), `Announce` |
| `RoomReset` | a part (gets a hold-to-use prompt) | none |
| `RoomGoal` | a trigger part where a level is finished | `Message`, `Id` |

`Input` takes a signal name or a combination: `PlateA & PlateB` (both, for co-op),
`PlateA | LeverA`, `!Alarm`, `(A & B) | Override`. The words `and`, `or`, `not` work too.
While the game runs, each room shows its live signals as `Signal_<name>` attributes, which
helps when wiring does not do what you expect.

The full option lists are at the top of each file in `src/server/Components/`.

## Project layout

```
default.project.json         Rojo project: what goes where in the place
src/shared/                  ReplicatedStorage.Shared: config, maths, expression language,
                             TowerMap (all 100 floors and their staircases)
src/server/                  ServerScriptService.Server
  init.server.luau           start-up: collision groups, build the tower, bind tags
  Services/                  grabbing, weighing, signals, checkpoints, notifications
  Components/                one file per tag
  Tower/                     where levels and connectors go, and building them
  Rooms/                     level builders, their layout data, and shared build helpers
src/client/                  StarterPlayerScripts.Client: grab controller and HUD
tests/run.luau               runs tests/suites/: logic, tower map and layout, each level
tools/bake.luau              builds the tower into a place file
tools/tower_map.luau         writes docs/TOWER_MAP.md from the map
tools/check_api.py           checks Roblox API names against an API dump
docs/                        the tower, the map, and a walkthrough per level
```

Tuning (reach, lift capacity, throw strength, player weight, lift speed) is in
`src/shared/Config.luau`.

## Checks

```sh
lune run tests/run.luau     # 62 tests: logic, tower rules and layout, each level
stylua --check src tests tools
selene src
curl -sLo API-Dump.json https://raw.githubusercontent.com/MaximumADHD/Roblox-Client-Tracker/roblox/API-Dump.json
python3 tools/check_api.py API-Dump.json
```

The tests check that the tower map follows every rule. They also lay out all 277 levels and
their connectors and check that nothing overlaps.

They build each finished level headlessly and check that:
- it fits its footprint, with its entrance and exits open
- no crate starts inside a wall
- lift platforms clear the building over their whole travel
- every door input is wired to something
- the puzzles are solvable with the weights the level has, and not easier than intended

They cannot check how it feels to play.

## What to playtest

These are the things only Studio can tell us:

1. **Carrying feel.** Picking up 10 and 20 KG crates, putting them down where you look,
   stacking two. Dragging the 60 KG steel crate. Values in `Config.Grab`.
2. **Truck bay.** Can you get out with one crate, and pull crates up over the edge after you?
3. **Shutter plate.** Does 40 KG open it, and does a crate under the shutter hold it open?
4. **Lift.** Riding up with the platform; loading cargo from the rider platform; recovering
   when B goes up empty.
5. **Touch and gamepad.** Button placement next to the jump button; aim assist.
6. **Two players.** Co-op weights, and whether a reset by one player annoys the other.
7. **Between levels.** The ladder from Level 1's exit up to Level 2. Each ladder climbs
   48 studs: is that too long?
8. **Level 2.** Each exit's solution, especially:
   - dragging the steel crate onto the lift and riding it up
   - riding the cargo platform into the pit and climbing out before the hatch closes
   - fuses settling in the socket trays

## Not done yet

- The other 275 levels (the map is laid out; each needs its room built).
- Sound, art, and proper lighting. The levels are lit by simple ceiling lamps, because the
  floor above blocks the sun.
- Saving progress between sessions.
- Two players carrying one object together (one holder at a time for now).
- Putting levels with no players nearby to sleep, and turning on `StreamingEnabled`. Neither
  is needed with two levels built, but both will be once there are many.
