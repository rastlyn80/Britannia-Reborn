# Ophidian Mage and Archmage on slopes and steps

ModernUO's Ophidian Mage and Archmage both use body 85. The terrain route retains the recovered Third Dawn rig, source staff and its animated socket, original hues and the four existing Enhanced fits. The body and staff are measured together so the tip of the staff cannot pass through the top tread while the body remains above it. The fall begins from the displayed model transform and freezes into static corpse graphic 0x2006, body 85.

| Replay | Classic | Enhanced |
| --- | ---: | ---: |
| Living full-skin poses | 4,650 | 5,890 |
| Clipped poses before correction | 2,580 | 2,930 |
| Clipped poses after correction | 0 | 0 |
| Decoded death and corpse handoffs | 80 | 112 |
| Sampled fall poses | 1,360 | 1,904 |
| Isolated native checks | 61 | 69 |

The geometry replay covered flat ground, slopes and a 22 cm tread, with the original staff mesh included. The starting joint shift at death stayed under two micrometres in both profiles. The frozen skin and staff settled about 2 mm above the support. The largest sampled living correction was about 234 mm in the Enhanced run on the highest tread. The visible lift remains a limitation of whole-body clearance on abrupt steps.

The isolated stock server used both classes with each of two disposable characters. Both connections received native movement and death. The normal client kept the staff on the original socket, showed the requested partial hue and retained the staff on the frozen corpse. The real stock Lightning spell cursor damaged a disposable Ogre. The fixture initiated the spell and sent controlled gesture packets for the fidget and selected Enhanced actions. Spontaneous AI casting and its choice of animation were outside this check.

The local work/creatures/native-form-audit/enhanced-source-gaps/common-forms-enhanced/ophidian-mage-living-source study contains the staged route, terrain and death drivers, before and after logs, and native receipt. The source and optional Enhanced fits retain the existing project provenance. The release includes the renderer and this report.
