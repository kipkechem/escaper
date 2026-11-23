# The tower

The game is a tower of 100 floors built from several overlapping staircases. Every level
is one floor. You climb from Level 1 at the bottom to Level 100 at the top.

The full map, floor by floor, is in [TOWER_MAP.md](TOWER_MAP.md).

## Staircases and level names

| Staircase | Letter | Column (x) | Difficulty |
| --- | --- | --- | --- |
| Easy | `E` | -128 | Easy |
| Medium | `M` | -64 | Medium |
| Main stair | none | 0 | Very hard (Level 1 is the tutorial) |
| Hard | `H` | +64 | Hard |

A level's number is its floor, and side staircases add their letter: on floor 12 there can
be `12E`, `12M`, `12` and `12H`.

## Rules

`src/shared/TowerMap.luau` holds the map and `TowerMap.validate()` checks it. The tests
fail if any rule is broken.

1. Every floor from 1 to 100 has a main-stair level.
2. Floors 99 and 100 are main stair only: every staircase rejoins the main stair before
   the final level.
3. Every exit goes up exactly one floor, to the same staircase or a neighbouring one.
4. A level has at most 3 ways out and at most 3 ways in.
5. Every level can be reached from Level 1, and Level 100 can be reached from every level.
6. Level 100 has no exits.

A level with several exits is a **fork**. Each exit belongs to a different solution, and
harder solutions lead to harder staircases. A level with several ways in is a **merge**.

## Building layout

- **Floors** are 64 studs apart: floor `n` is at y = 64 × (n − 1).
- **Footprint:** every level fits the same box in its own coordinates: x −26..26,
  z −42..100, y −16..44.
- **Entrance:** a 6 × 8 opening in the middle of the z = −42 wall, at floor level.
- **Exits:** 6 × 8 openings in the z = 100 wall at y 16, in up to three slots: x = −16
  (towards the staircase on the left), 0 (straight up), +16 (towards the right).
- **Switchback:** odd floors face +z, and even floors are turned 180°. So each level's exit
  end sits under the next floor's entrance end, and a builder must take its exit slots
  from `context.exits` instead of assuming left is left.

```
   side view (one column)               top view (one junction, odd floor below)

   floor n+1  ┌──────────────┐◄─ pad         ┌── pad (left) ──┐  ┌── pad ──┐  ┌── pad (right) ─┐
              │  entrance ─► │  ▲            │                │  │    ▲    │  │                │
              └──────────────┘  │ ladder     │ lane 3 ◄═══════╪══╪══╗ │    │  │                │
   floor n    ┌──────────────┐  │            │ lane 2         │  │  ║ │ ╔══╪══╪═════════► lane 2
              │       exit ─►│──┘            │ lane 1         │  │  ║ ▲ ║  │  │                │
              └──────────────┘               └─── exits: left (x−16), straight (x0), right (x+16)
```

**Connectors.** Each exit leads into a 24-stud landing zone beyond the wall, split into
three lanes of 8 studs:
- **Straight up:** a ladder shaft in lane 1 straight to the pad.
- **Right:** a corridor to lane 2, a ladder shaft, then a bridge to the right-hand column's pad.
- **Left:** the same through lane 3.

An entrance pad can only be reached from below, from the left and from the right. That is
where the 3-ways-in limit comes from.

All connectors are enclosed tubes, so nobody can hop from one route to another. A pad in
front of a level that is not built yet is walled off with an UNDER CONSTRUCTION sign. Each
connector starts with the "Level complete" trigger, and each pad has a checkpoint
(order = floor × 10 + 1) that announces the level.

## Adding a level

1. Check the level's id in [TOWER_MAP.md](TOWER_MAP.md), or change the map in
   `src/shared/TowerMap.luau` (`Runs` and `Links`) and run `lune run tests/run.luau` to
   check the rules.
2. Write a builder in `src/server/Rooms/`, with a layout module for its numbers, following
   `Switchboard.luau`:
   - Build in the level's own coordinates through `Build.new(context.frame)`.
   - Leave the entrance opening clear.
   - Put an exit opening (with whatever door the puzzle opens) at each `context.exits[i].localX`.
   - Number checkpoints `floor × 10 + 2` and up. The pad uses `+ 1`.
   - Keep everything inside the footprint, and put a lid on the room so stacked crates cannot
     climb out.
3. Register it in `Tower.Builders` in `src/server/Tower/Tower.luau`.
4. Add a suite in `tests/suites/` that runs `RoomChecks.run` and checks the puzzle's sums,
   and add it to `tests/run.luau`. `RoomChecks.run` covers the footprint, clear openings,
   loose objects, lift travel, wiring and checkpoints.
5. Run `lune run tools/tower_map.luau` to refresh the map, then rebuild and bake the place.
