# Reptalon and Rend breath timing

An unmounted Reptalon or Rend keeps the existing original rig, `Attack2`-derived breath, and animated mouth socket through classic animal attack groups 5 and 6 and Enhanced melee type 0. The five-frame group 12 starts the breath. The separate ten-frame group 12 still selects its alternate fall.

The World replay passed 12 checks per mode. It checked both melee packet types during windup, the exact projectile origin, melee after the window, and a matching dyed static corpse after death interrupted the breath. It also applied a rider's ordinary group 12 to a character wearing the native Reptalon mount item. The mounted presentation remained a mount. ModernUO internalizes the mount while it is ridden. Airborne mounted travel remains a separate verification gap.

The isolated ModernUO trials covered both constructors and both modes. Stock combat AI selected Fire Breath and dealt native damage. A second trial sent an animal melee packet during the windup. All four resulting fireballs still started at the animated mouth and dealt damage. The fixture positioned the target and timed that extra packet. Wild encounters remain open.

Run the World replay with Godot `--headless --path Viewer --script res://../scripts/test-reptalon-breath-world.gd`. Add `-- --enhanced-creature-actions` for Enhanced.
