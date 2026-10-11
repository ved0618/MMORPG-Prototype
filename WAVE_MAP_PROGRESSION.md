# Wave-based map progression

The map flow has been changed to sequential levels.

- Maps progress in order: `001 -> 002 -> ... -> 026`.
- Old map portals are removed from all generated map scenes.
- The legacy biome-transition teleport is disabled.
- Every map has a solid collision boundary, so players cannot walk out of it.
- Each map starts a finite wave using its existing three monster spawners.
- Each spawner creates 2 monsters for the wave and does not respawn them.
- When all monsters in the current map are dead, a 5-minute (300 second) delay starts.
- After the delay, the server moves every connected player to the center of the next map.
- After every completed level, every player's maximum HP is increased by 20%.
- The increased HP is stored per player and survives death/respawn.
- Map 026 receives the same three spawners at runtime because it previously had none.
- `Scripts/map_generator.gd` no longer generates portals, so regenerating maps keeps the new behavior.

To change the 5-minute delay, edit `LEVEL_DELAY` in `Scripts/map_manager.gd`.
To change the number of monsters per spawner, edit `max_alive` in `Scenes/spawner.tscn`.
