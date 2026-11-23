# Level 2: The Switchboard

The tower's first fork. Three exit doors lead to three staircases, and each opens through a
harder use of the same few parts:
- **fuses** (5 KG), which go in sockets
- **weight**, on plates
- the **counterweight lift** from Level 1

Numbers are in `src/server/Rooms/SwitchboardLayout.luau`, and `tests/suites/level2.luau`
checks them against the game's rules.

## The room

- **Main floor:**
  - the glass **fuse cage** (fuse 1) and its plate
  - five crates (20, 20, 20, 10, 10 = 80 KG)
  - the 60 KG **steel crate** (drag only)
  - the freight lift
- **Ramp** up to the mezzanine, along one wall. It is 4.6 studs wide, so crates fit up it
  but the 5-wide steel crate does not. A sign at its foot reads "NO HEAVY LOADS".
- **Lift pit,** under the cargo platform. Its ladder alcove holds **fuse 3** and is covered
  by a grate. The grate only opens from below, with a timed lever (8 seconds).
- **Mezzanine** (16 up):
  - the three exit doors, each with a sign saying where it leads and what it needs
  - plate H, with a tall rack beside it and a shelf above it holding **fuse 2**
  - the main plate, at the lift landing
  - the sockets

## The three exits

### Medium: to 3M (needs a fuse in socket M)

The fuse cage opens while its plate holds 40 KG. Put two crates on it, take fuse 1, carry
it up the ramp and set it in socket M.

### Hard: to 3H (needs a fuse in socket H and 60 KG on plate H)

Fuse 2 is on a shelf 22 studs above the mezzanine, out of reach even with a jump. Carry two
20 KG crates up the ramp and stack them on plate H, under the shelf, then climb the stack
and take the fuse. The trap is that two crates weigh only 40, so the plate also needs you:
socket the fuse (socket H is on the rack, within reach of the stack) **while you are still
standing on the stack**. That makes 40 + 25 = 65, and the door opens and stays open.

### Very hard: to Level 3, the main stair (needs fuses in sockets A, B and C, and 120 KG on the main plate)

You need all three fuses:
- **Fuse 1:** from the cage, as above.
- **Fuse 2:** from the shelf, as above.
- **Fuse 3:** jump onto the lift's cargo platform. You alone outweigh the empty rider cage,
  so it sinks into the pit. Take the fuse, pull the hatch lever and climb the ladder out
  within 8 seconds.

Then the main plate needs 120 KG. Every crate plus you is only 80 + 25 = 105, so the crates
alone can never do it. The insight is to **lift the unliftable**:

1. Drag the steel crate onto the rider platform (it sits flush with the floor).
2. Load the cargo platform with more than 72 KG, which beats 60 for the steel plus 10 for
   the cage plus the 2 KG margin. Either every crate (80) or you plus 50 KG of crates will
   do, and the steel crate rides up to the mezzanine.
3. Go up the ramp and drag the steel crate off the lift onto the main plate, right beside it.
4. Bring 40 KG of crates (two 20s) onto the plate. If they went down with the cargo, the pit
   ladder is the way out with them.
5. Stand on the plate: 60 + 40 + 25 = 125. With the three fuses in their sockets, the door
   opens.

The order matters: crates are needed in three places (cage plate, stack, lift cargo), and
the cage closes again when its plate is unloaded. You have to plan where every crate goes.

## Co-op

- Two players on the main plate with every crate (50 + 80 = 130) skip the steel crate. This
  is allowed: friends are meant to help.
- On plate H, a friend standing on the plate replaces 25 KG of crates.
- Once any exit door opens it stays open for everyone.

## Recovery

- **RESET ROOM** consoles on the floor and on the mezzanine put every crate and fuse back
  and switch the hatch lever off. Opened exits stay open.
- Respawning puts you at the mezzanine checkpoint once you have reached it.

## To check in playtest

- Dragging the steel crate onto and off the rider platform.
- The cargo platform taking a player down smoothly.
- Climbing out of the pit in time.
- Fuses resting in the socket trays.
- Whether the shelf fuse is out of reach from the plate with a jump. The sums say yes, but
  only by 0.3 studs.
