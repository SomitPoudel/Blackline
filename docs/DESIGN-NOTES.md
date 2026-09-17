# Implementation notes

The simulation stores world positions in two dimensions and the renderer places them in a 3D cutaway world. Grid cells hold walls, furniture and door states. Breadth-first routing permits closed door cells and triggers a timed opening interaction when an officer reaches one. Furniture blocks navigation; taller cabinets also block sight and shots.

Visibility combines facing angle, light level, distance, walls and closed doors. The squad's visible-cell union is uploaded into a fog texture. Characters outside current visibility are hidden independently of the texture. A faded floor-plan outline supplies architecture without revealing characters or furniture. Last-known suspect markers expire after 20 simulation seconds.

Noise uses weighted propagation through neighbouring cells. Closed doors and walls increase the cost. Each recipient receives an uncertain source location and updates its own state. Loud disturbances and visual evidence retain high alert. Confirmed sightings create last-known positions; NPCs do not keep tracking a hidden moving officer.

Radio reports are delayed events. A dead, secured or surrendered sender cannot complete a report. An active jammer blocks the sender or receiver locally, and nearby NPCs can exchange a warning verbally. Existing knowledge is not erased by activating the jammer. Loud incident reports are rate-limited per NPC to prevent radio flooding.

The weapon catalogue contains game-defined magazine capacity, firing interval, reload duration, pellet count, recoil/spread approximation, weight and sound power. Projectiles sample their paths and resolve the first blocking surface or character. Officers avoid shooting directly through allies or civilians; spread can still create risk. Shotguns reload per shell. A light is destroyed only when a shot reaches it without hitting an intervening obstacle or character.

Career saves store credits, reputation, equipment access, individual loadouts, mission completion and experience. Operation snapshots preserve integer types explicitly because JSON otherwise restores numbers as floating-point values. They also preserve RNG state so loading does not reroll the operation.

Difficulty grows through mission data, not enemy health inflation. The current generator produces variations of a common six-room layout with different contents, lights, patrol capability, radio availability, civilian counts and enemy discipline. Additional hand-authored buildings can replace this generator later without replacing the perception or combat systems.
