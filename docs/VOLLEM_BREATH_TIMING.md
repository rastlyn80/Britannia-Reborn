# Vollem breath and overlapping melee

Body 293 keeps the existing Reptalon-derived Vollem mesh, articulated muzzle, native colours and static corpse. See [the Ter Mur construct record](TER_MUR_GARGOYLES_AND_CONSTRUCTS.md) for the donor, renderer and native crafting evidence.

An overlapping melee cue previously replaced the visible breath before the server projectile. The World dispatch now holds the existing breath through either form of melee packet. Death still interrupts the motion. The decoded Ter Mur replay failed at the new overlap check before the fix and passed 141 checks in each client mode afterwards.

In Classic and Enhanced disposable ModernUO trials, the fixture invoked Vollem's actual ability and sent a competing melee cue after 993 and 1,000 ms respectively. The server projectile launched at 1,301 and 1,309 ms, with zero measured separation from the animated muzzle, and dealt 32 and 30 damage. The earlier native constructed-pet trial already observed stock AI using breath under a player attack order. The new trials exercise the timing conflict directly.
