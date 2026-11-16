# Medusa

Body 728 uses the wingless refit of Third Dawn body 149. The biped keeps its original skeleton and weights. The fit adds nine articulated snake locks, hand grips for a composite bow, a back shield and a quiver. The 81-joint modern rig has 22,934 skinned vertices. Its slate-blue skin, gold trim and equipment accept the separate native creature and bow hues. The back shield and quiver are part of Medusa's body mesh.

Enhanced 4.0.117.33 supplied 820 decoded AMOU frames in 17 groups in `AnimationFrame2.uop`. The input manifest pins the URL and digest of every referenced member and the three donor scenes. No usable body-728 creature row was found in the checked Third Dawn tables. See the [Abyss source audit](UNDERWORLD_SENTINEL_AND_ABYSS_REFERENCES.md).

Prepare the body-149 donor and the existing Third Dawn bow used by the centaur. Expand the Enhanced members into a local directory under the names `ec-frame-728-<group>.bin`. Run `python -B scripts/prepare-medusa.py --reference <directory>` to install the three content-addressed scenes under `Viewer/local-art/creatures/medusa`. Run `scripts/verify.ps1` for the prepared World and terrain checks. The source payloads, fitted scenes and captures stay outside Git.

The shipped Abyss spawner at Ter Mur (818, 927, -15) produced body 728 with 60,000 health, native sound 1554 and an equipped composite bow on an isolated server. Its normal archer AI chose the gaze, applied stone hue 761 and suspended movement and damage until the native timeout. The timeout restored the previous hue 1141 and the target's original movement and vulnerability.

Both live World clients passed 13 checks. The fixture invoked a genuine weapon swing after the natural gaze cleared. The resulting native arrow packet launched from the animated nock with zero measured origin gap in both profiles. The fixture then invoked native death and both clients showed a static body-728 corpse with dye 1141. Autonomous arrow selection still needs verification.

The World replays passed 49 Classic and 57 Enhanced checks on headless and Forward+. They exercised the fitted gestures, native composite bow equipment packet, drawn string and nock, two falls, and both corpse and death packet orders. The dyed frozen body retained the snakes and the baked back equipment. Terrain samples checked 2,340 grounded poses across flats, slopes and a 22 cm step. Minimum clearance was 2.5 mm and the highest upward correction was 22.6 cm.

The pinned server uses the composite bow and Archer AI as the initial adaptation. It still needs the Ironwood item properties, spell selection, Venomous Bite, Gorgon Lens deflection, cloned and summoned helpers, harvesting and reward progression. Some source poses share a fitted gesture. The shield is currently flat at its edge and the head and snake shapes need closer sculpting. [Pinned Medusa reference](https://github.com/ServUO/ServUO/blob/d76bf4443cf76d081ddaf8f57c87ff33749256af/Scripts/Mobiles/Bosses/Medusa.cs)
