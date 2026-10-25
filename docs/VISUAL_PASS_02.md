# Shared architecture and living environment pass

## Architectural corrections

The previous contextual gable rule was incorrect: it moved a source wedge assembly to a nearby wall without proving an exterior relationship, leaving a strip of plaster visible indoors. Unsupported source gable assemblies are now omitted from perspective rather than relocated. Exterior gable closures belong to the joined roof envelope, avoiding duplicate source-wedge faces. Source/map comparison retains original records and positions.

Explicit source corners now use connected half-wall arms on the same centre planes as adjacent source walls. The previous full panels offset by 0.42m did not meet the neighboring panels. Perpendicular wall ends without a corner record receive bounded half-cell joins. Narrow one-Z storey seams get visual height extensions. Door jambs close the clearance around the closed model. Openings stay in their source cells. Complementary arch ends separated by up to four cells form one wide entrance; an intervening source wall blocks assembly. This closes the bank entrance's accidental upper hole.

These are catalogue/topology rules in Facade and Reconstruction, not coordinate patches. Tests rotate and translate independent layouts to unrelated locations. The current crop audit reports 14 corner records, 34 connected branches, 20 implicit wall joins, 33 storey seams, and no isolated corner records. Rendered coverage retains all 2,689 records; 185 are grouped contributors, 35 clipped roof fragments are retained but suppressed in perspective, and four contextual owners are suppressed (three redundant/unsupported source gable assemblies and the elevated duplicate bench). Current perspective collision is 77,898 triangles.

## Visual changes

Furniture gets small geometric bevels, spaced supports along its footprint, shared timber materials, mild grain and roughness. Paving is smaller and less uniform, roof tiles finer and lower contrast, and ambient/direct light balance gives more shape to the existing assets. Roof undersides use timber lining. This is a first refinement pass; architectural proportions, complex roof intersections, terrain banks, window detail, prop variety and final art direction remain unfinished.

Tree crowns sway slowly, grass and small plants bend less and flutter gently, and water uses two travelling ripple directions with changing normals and highlights. Wind is weighted to zero at the bottom of each mesh; maximum crown displacement is 0.14m. Position-dependent phases use source/world coordinates so neighboring instances move coherently without identical motion. The shader changes visual vertices only; source coordinates, navigation and server movement do not change. Water stays planar to avoid cracks between source tiles. North-up comparison disables nature deformation. Existing CC0 textures are unchanged; the shaders and bevel geometry are project code, with no new third-party assets.

## Validation and reproduction

- `scripts/verify.ps1`: 135 offline checks, converter/extension builds and actual crop load.
- `scripts/capture-visual-pass.ps1`: actual GPU tree, grass and water motion checks; screenshots and twelve controlled-time environment frames. Each motion check compares rendered pixels at two times and verifies that the scene root transform stays fixed. All three pass on the RTX 2070 SUPER / compatibility renderer.
- Local outputs: britain-interior.png, visual-street.png, visual-roof-corners.png, nature-frame-00..11.png, wind-test images and visual-coverage.json. living-environment.gif is a ping-pong preview assembled from the rendered frames; source-derived images remain ignored locally.

## Extension to larger maps

Loading a larger IR reruns these same rules automatically for known IDs. The audit output records connections, suppression reasons, offsets and unresolved IDs. No Britain coordinate is baked into reconstruction rules. This does not prove every building type across Britannia: the catalogue currently covers 187 IDs, and additional IDs need explicit mappings. Streamed chunk generation must load a neighboring halo and keep deterministic cross-chunk ownership before boundary-spanning structures can be claimed seamless. Other regions/facets still need representative visual and geometry checks. Do not fill absent source records blindly: doors, windows, passages and crop edges can be intentional openings.
