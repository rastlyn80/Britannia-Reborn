# Slasher of Veils

Body 741 is based on the Third Dawn daemon body 9. The red daemon donor provided the horns, limbs, claws and articulated tail. The refit removed wing geometry, including unused vertices that would otherwise affect alignment and corpse bounds. It lengthened the tail and claws and added a dark ragged mantle, violet clasps and 20 cloth joints. The modern and rounded treatments contain 21,385 weighted vertices and a 75-joint rig. All three treatments retain the donor's base skinning.

Enhanced 4.0.117.33 supplied 1,105 decoded AMOU frames in 17 groups from `AnimationFrame2.uop`. The input manifest records the precise URL and SHA-256 of each member, along with the hashes of the three Third Dawn donor scenes. A dedicated creature body 741 was absent from the checked Third Dawn tables. The model and textures remain local. [Abyss source audit](UNDERWORLD_SENTINEL_AND_ABYSS_REFERENCES.md)

Prepare the body-9 donor and expand the Enhanced members as `ec-frame-741-<group>.bin` in a private folder. Run `python -B scripts/prepare-slasher-of-veils.py --reference <directory>`, which validates the references and installs the three hashed scenes under `Viewer/local-art/creatures/slasher-of-veils`. When the assets are present, `scripts/verify.ps1` exercises the client and terrain routes.

The shipped Abyss spawner at Ter Mur (749, 475, -17) produced body 741 within its home range. The isolated placement trial confirmed the sound, mana pool and Paralyzing Blow. The two melee callbacks also produced fire damage with the expected 30 mana cost and transferred the drained mana into the caster's available deficit.

Classic and Enhanced each passed 13 isolated live checks. Repeated normal movement across the eight-tile approach boundary exercised the chance to trigger fear. The observer saw the server freeze the test character, send the fitted cast cue, and restore movement after the timer. The fixture invoked both melee callbacks and checked the actual effect packets. Native death then produced a visible frozen body and mantle with graphic `0x2006`, body 741 and dye 1141.

World replays passed 41 Classic and 51 Enhanced checks on headless and Forward+. They covered fitted actions and both corpse and death packet orders, including the final dyed static mesh. The terrain witness sampled 2,808 poses across flats, slopes and a 22 cm step. Minimum clearance was 2.5 mm and the highest upward correction was 22.3 cm.

The spell retaliation code still needs a live test. Actual approach tests covered connected player characters. Artifact rewards and less distinct source variations need further work. The arms, claws and mantle still differ from the exact 2D silhouettes. The pinned behavioural source has blob `da00813322a801eda5efda961349233a5fa70628`. [Pinned Slasher reference](https://github.com/ServUO/ServUO/blob/d76bf4443cf76d081ddaf8f57c87ff33749256af/Scripts/Mobiles/Bosses/SlasherOfVeils.cs)
