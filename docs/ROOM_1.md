# Room 1: The Loading Dock

A tutorial room. It teaches grabbing, weight, and the counterweight lift, then makes you
combine them. Everything can be solved alone. A second player helps but is never required.

Numbers live in `src/server/Rooms/LoadingDockLayout.luau`. `lune run tests/run.luau`
checks the puzzle sums against the game's real rules, so if you change a weight, run it.

## Rules the player can see

- Every crate has its weight stencilled on it (10, 20 or 60 KG).
- A player counts as **25 KG** on plates and lifts, plus whatever they are carrying.
- You can lift up to 45 KG. Heavier things can only be dragged along the floor.
- Plates and lift platforms show a live weight gauge.

## Layout

```
 z
 ^   EXIT CORRIDOR  (goal, "Room 2 coming soon")
 |   ─────┤ EXIT DOOR ├─────           (in the back wall, on the mezzanine)
 |   MEZZANINE, 16 high   [EXIT PLATE 30]   checkpoint 3
 |   ═══════════════[B]─[A]═══  fire ladder (drops when the exit opens)
 |   LIFT HALL        lever   3 crates      checkpoint 2
 |   ─────────┤ SHUTTER ├─────────
 |   DOCK FLOOR   [SHUTTER PLATE 40]   3 crates + steel crate
 |   ──────┤ dock edge, 9 high ├──────
 |   TRUCK BAY (spawn, 2 crates)
```

## Walkthrough

### 1. The truck bay: grab and stack

You spawn in a trailer whose floor is 9 studs below the dock. You can jump 7.2, so you
cannot climb out. Put one of the two 10 KG crates against the dock edge, stand on it and
jump up. Then lean over the edge and pull the other crates up after you. The trailer has two
crates, so the step crate can come too.

### 2. The dock floor: the weighted shutter

The shutter to the lift hall opens while its plate carries **40 KG**, and closes when the
load drops. Standing on it yourself (25) is not enough, and you cannot stand on the plate
and walk through the shutter at once anyway. Ways to open it:

- two 20 KG crates
- a 20 and two 10s
- drag the 60 KG steel crate onto it (too heavy to lift, but it slides)
- with a friend: one player standing on the plate holding a 20 KG crate (25 + 20 = 45)

While the shutter is open, carry spare crates through. On the far side, the **shutter
override lever** holds it open from the inside, so you can go back for the crates on the plate.

A crate left under the shutter props it open: the shutter stops rather than crush it.

### 3. The lift hall: the counterweight lift

Two platforms share one rope. **B** (the rider cage) sits flush with the floor; **A**
(cargo) is 4 studs up, over a pit. The heavier side sinks. The cage itself weighs 10 KG,
so an empty lift rests with B at the bottom. To ride B up to the mezzanine, A must
outweigh B (you, plus anything you carry, plus the 10 KG cage) by more than 2 KG.

The trap: load A first and B rises without you. The way to do it is to stand on B and
then load A, either from crates you carried onto B or from the floor around you. With
only the three crates in the hall (40 KG) you rise alone: 40 against 25 + 10.

If B went up empty, take crates off A (it is down in the pit: there is a ladder in the
corner), or use the RESET ROOM console.

### 4. The mezzanine: the exit plate

The exit opens once its plate carries **30 KG**, and then stays open. You alone weigh 25,
so you need a crate up there with you. If you carry a 10 KG crate while riding, you weigh
35 + 10 cage = 45, and the hall's 40 KG of cargo is no longer enough. You have to bring
crates through from the dock (using the shutter override lever) and put at least 48 KG on A.

Other ways up for a crate:

- throw it up while riding
- with a friend: two players on the exit plate (50) need no crate at all

When the exit opens, the fire ladder drops so anyone still below can climb up.

## Alternatives the numbers allow

These are intended. Multiple solutions are a design goal:

- Dragging the steel crate onto the shutter plate frees every light crate for later.
- Co-op lift: one player on A holding a 20 KG crate (45) lifts a lone rider on B (35).
- If the two sides are within 2 KG of each other the lift stops where it is, even midway.
  Players who change the load while it moves can use that to park it at other heights.

## Recovery

- RESET ROOM consoles (one on the dock, one in the hall) put every crate back and switch the
  lever off. Latched doors (the exit, the fire ladder) stay open. There is a 10 second cooldown.
- Crates that fall out of the world return to their start.
- Respawning puts you at your furthest checkpoint.
