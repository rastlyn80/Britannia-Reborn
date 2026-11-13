# Red and Black Solen worker terrain

Red Solen Worker 781 and Black Solen Worker 805 retain their separate source meshes, UV atlases and native colours. The Black Solen keeps native hue `0x453`. Both use the recovered 42-joint rig and its six walking legs. The optional Black Solen alert and other Enhanced gestures retain their existing fits.

The first terrain replay found 596 intersections in 6,200 Classic samples. Both workers could clip a 22 cm step by the full height of the tread. Attack2 and LieDown also clipped the steeper test slope. The terrain adapter retains the six-leg support and adds weighted-mesh clearance across both treads and during the two affected slope poses. The updated replay cleared the floor tolerance in all 6,820 Classic and 8,370 Enhanced complete-skin poses, including WorkerBrace. Attack2 can still visibly lift the whole mesh by about 220 mm between samples at the step edge.

The corpse replay passed 112 Classic and 136 Enhanced handoffs, covering 1,904 and 2,312 complete-skin samples. The entry preserves the displayed pose within 1 micrometre. It eases from the planted pose to the final 2 mm clearance. The lowest transitional sample was 0.501 mm into the surface. The final model freezes into native graphic `0x2006` with the original worker's body and hue.

The two isolated clients passed 47 Classic and 49 Enhanced checks across four stock construction cases per mode. Both saw native Walk and Run, distinct Classic Fidget2 and visible static corpses. The Enhanced run also selected the Black Solen alert with a controlled packet. Two earlier Enhanced attempts with a fixed delay received a running packet without observing the Run animation. The final test waits for the previous motion to finish before sending the next. This verifies separate native gait segments. Closely spaced walk-to-run packets remain in review.

The accepted source art and earlier native Solen friendship evidence are documented in [Original Solen workers](SOLEN_WORKERS.md). The new local replays and evidence are under `work/creatures/native-form-audit/enhanced-source-gaps/common-forms-enhanced/solen-workers-living-source/`.
