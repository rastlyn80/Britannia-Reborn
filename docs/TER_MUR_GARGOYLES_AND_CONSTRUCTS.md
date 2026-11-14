# Ter Mur Gargoyles and Sutek constructs

Four staged 3D presentations use original Third Dawn donor rigs. The male and female Gargoyles use the body 4 winged rig with distinct proportions and colours and a folded walking silhouette. Both accept basic Gargish leather, cloth and Cyclone graphics. Head horns and facial horns attach to the animated head and use their separate equipment hues. The wider Gargoyle wardrobe and the exact racial action sets remain open.

| Server body | Character | 3D donor | Changes |
| --- | --- | --- | --- |
| 293 | Vollem | Reptalon 276 | Compact frame, pale surface and a wing cycle adapted from the donor's running animation |
| 666 | Male Gargoyle, including Agralem | Gargoyle 4 | Shorter wings in grounded poses, darker slate body, basic equipment |
| 667 | Female Gargoyle | Gargoyle 4 | Narrower frame and lighter slate skin with the same rig and basic equipment |
| 739 | Leather Wolf and its fellows | Grey Wolf 25 | Broader frame, layered brown material regions following the source skin |

The new scenes retain donor geometry, joint weights and animation assets. They are authored adaptations fitted to a subset of the Enhanced 2D references. The two Gargoyles share an adapted mesh. Vollem and Leather Wolf remain candidates for additional shape and material work against the original references.

The Classic and Enhanced decoded World tests each passed 140 checks, including twelve fully skinned walk samples per form, decoded horn and starter-cloth packets, separate equipment dyes, the Vollem mouth origin and a matching static corpse for all four bodies. Gargoyle corpses retain the equipped Cyclone and horn sets when the corpse supplies matching equipment. Eight body renders and six horn close-ups were inspected using Forward+ Vulkan. The terrain replay covers one fixture, and the fitted motion still needs a frame-by-frame parity review.

Two isolated server clients each used the stock racial flight request for male body 666 and female body 667. The other client received the airborne flag and the original ten-frame takeoff and landing groups 60 and 61. Both characters repeated the flight sequence after restart. These trials passed 25 checks before restart and 18 afterwards. In the staged viewer the Gargoyle-only **Take flight** control sends the same request and changes to **Land** when the server reports flight.

## Gargoyle creation and horns

The character creation screen offers Gargoyles when both local models are installed and the server advertises Stygian Abyss support. A native creation trial used gender and race bytes 6 and 7. The other client saw the male's 0x4259 head horns and 0x42AD facial horns with independent hues 0x70D and 0x765. The female used head graphic 0x42B0 with hue 0x6E2. The male received starter cloth chest 0x0406 and legs 0x040A. The female received 0x0405 and 0x0409. The native trial passed 33 checks on creation and 24 more after restart. Both retained their cosmetics, bodies and serials and repeated native flight.

The pinned ModernUO build applies the Human skin clamp before assigning the player's race. Both different Gargoyle skin submissions came back as native hue 0x8422. The creation screen previews that server result and only offers horn and facial-horn colours at present. The in-world renderer takes the current native skin hue. Stock starter clothing uses fitted donor regions with a matte cloth finish. The cloth arms, kilts and legs still need dedicated folds and silhouette work.

The Classic item archive returned one identical inventory sprite for all 20 horn graphics. The distinct paperdoll layers in `gumpartLegacyMUL.uop` provide shape references for the authored meshes. The archive begins with `4D 59 50 00` and its SHA-256 is `e7d9b9a8f4e28a36b18e9afca36035b879f48a4962d5a030d7be1a68fe5ad564`. The SHA-256 of `tiledata.mul` is `382388dc5b4f78e9aad923bf5bf20387d15e22716b3199974a36891ba2da9624`. Read the tile's animation field, add 50000 for the male or 60000 for the female, and decode the resulting graphic with the converter's `gump-art` command. In a scratch folder, a representative query is `dotnet Converter.dll gump-art <Classic-folder> <local-output.json> 50485,50665,50647,50657,50661,60656,60660`. Female 0x42B0 is valid in the pinned server and uses existing layer 50647 as its fit reference. The mesh recipe covers eight male, nine female and four male facial choices. The reused ID 0x42B0 retains distinct head and facial equipment layers. Paperdoll references and rendered images remain local.

The login protocol's eight checks passed. The general login smoke check timed out before getting the production server list. The isolated creation trial entered the world and reconnected after a real save independently of that smoke check.

Build the local scenes with `scripts/bake-ter-mur-creatures.gd` in the project Viewer, pointing `BR_TER_MUR_OUTPUT` to an existing absolute output directory. The recipe checks the locally accepted donor assets before loading them. Put the generated `profile.json` and its hash-named scene files under the ignored `Viewer/local-art/creatures/ter-mur-prepared/` directory to enable them. The runtime rejects a missing or changed scene. The original art, sprite samples, generated binaries and screenshots remain local.

## Native construction

Leather Wolf and Vollem use their native Mobile IDs and one and two follower slots respectively. The recipe uses a basic assembly, a Power Crystal and two Void Essence for the wolf or three for Vollem. Activating the wolf assembly requires 100 leather and a flask of oil. The Vollem activation follows the official live guide with 50 leather and 25 white dragon scales. The pinned community script uses 50 bronze ingots for Vollem.

The isolated server tests passed 47 checks for each constructed pet before restart and 30 for Leather Wolf and 27 for Vollem afterwards. Two clients confirmed crafting, ingredient use and secure transfer. The native repair menu restored 40 hit points at a cost of eight iron ingots. Ordinary healing left the damage intact. Both pets reloaded alive under the new owner with the same serial, full health and the correct follower slots. Leather Wolf summoned three helpers in combat and dismissed them upon death. Under a real attack order Vollem autonomously sent the moving fire breath effect 0x36D4 to both clients, followed by 48 damage to the isolated target. Both clients also received the native corpse identities. The fixture supplied ingredients and targets and triggered the final deaths.

The Classic and Enhanced World replays preserve the stock fire-breath windup and place the moving effect at the articulated head. The official Tinkering guide supplies the recipes, and the pinned code supplies the base statistics and combat references.

## Sources

- [Official mechanical pet construction and care](https://uo.com/wiki/ultima-online-wiki/skills/tinkering/mechanical-pets/)
- [Official tinkering recipe table](https://uo.com/wiki/ultima-online-wiki/skills/tinkering/tinkerered-craftables/)
- [Pinned Vollem mobile](https://github.com/ServUO/ServUO/blob/d76bf4443cf76d081ddaf8f57c87ff33749256af/Scripts/Mobiles/NPCs/Vollem.cs)
- [Pinned Leather Wolf and its fellows](https://github.com/ServUO/ServUO/blob/d76bf4443cf76d081ddaf8f57c87ff33749256af/Scripts/Mobiles/Normal/LeatherWolf.cs)
- [Pinned community clockwork assembly](https://github.com/ServUO/ServUO/blob/d76bf4443cf76d081ddaf8f57c87ff33749256af/Scripts/Items/Quest/ModifiedClockworkAssembly.cs)
