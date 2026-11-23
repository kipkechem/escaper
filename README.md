# Escaper

A physics-puzzle escape room for Roblox. The puzzles take after Human Fall Flat: real weight,
counterweights, levers, things you can carry and stack, more than one solution, and no
on-screen instructions beyond stencilled weights and signs. The character is a normal Roblox
avatar that can grab, carry, drag, turn and throw objects.

**Status:** first milestone. The core systems work in code and Room 1, *The Loading Dock*, is
built as a grey-box level (plain shapes, no art or sound yet). It has not been playtested in
Roblox Studio yet; see [What to playtest](#what-to-playtest).

## Open it in Roblox Studio

You need [Rokit](https://github.com/rojo-rbx/rokit) (installs the tools at the versions in
`rokit.toml`) and Roblox Studio.

```sh
rokit install
mkdir -p build
rojo build -o build/escaper.rbxl
lune run tools/bake.luau build/escaper.rbxl   # optional: puts the room into the file
```

Open `build/escaper.rbxl` in Studio and press **Play** (F5). To test co-op, use the
**Test** tab: choose 2 players and **Start** (local server).

`tools/bake.luau` runs the room builder ahead of time, so the room is visible in Studio's
edit mode and you can move things by hand. Without it, the server builds the room when it
starts. Either way, the server only builds a room that is missing from `Workspace.Rooms`.

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

Room 1's walkthrough, numbers and alternative solutions: [docs/ROOM_1.md](docs/ROOM_1.md).

## Building puzzles in Studio

Every puzzle piece is a **tag** plus a few **attributes** on a part or model, so new rooms
can be built in Studio without code. Add tags in the Properties window (Tags section) and
attributes under Attributes. Wiring works by name: a plate's `Output` turns a signal on,
and a door's `Input` listens for it.

| Tag | Put it on | Attributes |
| --- | --- | --- |
| `Room` | a model holding one room | `RoomName`. Signal names are local to their room. |
| `Grabbable` | an unanchored part, or a model of welded parts | `Mass` (sets the weight), `DisplayName` |
| `PressurePlate` | an anchored part (its top face) | `Output`, `RequiredMass`, `Label`, `SensorHeight` (14), `ShowGauge` (true) |
| `Lever` | a model with an anchored `Handle` part (optional `Base`, `Lamp`) | `Output`, `Mode` (`Toggle` or `Timed`), `Duration`, `Label` |
| `Door` | an anchored part or model (also gates, bridges, ladders) | `Input`, `OpenOffset` (default: up by its height), `OpenTime`, `Latch` |
| `Indicator` | a part that lights green | `Input` |
| `CounterweightLift` | a model with parts `PlatformA` (at its top) and `PlatformB` (at its bottom) | `Travel`, `Speed`, `TareA`, `TareB`, `Deadband`, `Output` (on when B is up), `LabelA`, `LabelB` |
| `Checkpoint` | a trigger part, or the SpawnLocation | `Order` (higher is further) |
| `RoomReset` | a part (gets a hold-to-use prompt) | none |
| `RoomGoal` | a trigger part at the exit | none |

`Input` takes a signal name or a combination: `PlateA & PlateB` (both, for co-op),
`PlateA | LeverA`, `!Alarm`, `(A & B) | Override`. The words `and`, `or`, `not` work too.
While the game runs, each room shows its live signals as `Signal_<name>` attributes, which
helps when wiring does not do what you expect.

The full option lists are at the top of each file in `src/server/Components/`.

## Project layout

```
default.project.json         Rojo project: what goes where in the place
src/shared/                  ReplicatedStorage.Shared: config, maths, expression language
src/server/                  ServerScriptService.Server
  init.server.luau           start-up: collision groups, build rooms, bind tags
  Services/                  grabbing, weighing, signals, checkpoints, notifications
  Components/                one file per tag
  Rooms/                     room builders and their layout data
src/client/                  StarterPlayerScripts.Client: grab controller and HUD
tests/run.luau               unit, puzzle-number and room-geometry tests (Lune)
tools/bake.luau              builds the rooms into a place file
tools/check_api.py           checks Roblox API names against an API dump
docs/ROOM_1.md               Room 1 design and walkthrough
```

Tuning (reach, lift capacity, throw strength, player weight, lift speed) is in
`src/shared/Config.luau`.

## Checks

```sh
lune run tests/run.luau     # 30 tests: logic, Room 1 sums, geometry and wiring
stylua --check src tests tools
selene src
curl -sLo API-Dump.json https://raw.githubusercontent.com/MaximumADHD/Roblox-Client-Tracker/roblox/API-Dump.json
python3 tools/check_api.py API-Dump.json
```

The tests build Room 1 headlessly and check that no crate starts inside a wall, that both lift
platforms clear the building over their whole travel, that every door input is wired to
something, and that the room is solvable with the weights it has. They cannot check how it
feels to play.

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

## Not done yet

- Rooms 2 to 5, sound, lighting and art.
- Saving progress between sessions.
- Two players carrying one object together (one holder at a time for now).
