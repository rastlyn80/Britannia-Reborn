"""Authored Lich gestures on the preserved source hierarchy; no source-clip claim."""
def install(body,clips,authored,aliases,stem,humanoid):
    assert stem in ['liche_liche_retro','liche_liche_lord_retro']
    for label in ['Cast','Pillage','Attack2','Attack3']:
        if label in clips:continue
        clips[label]=humanoid.gesture(body,clips['Idle'],label)
        if label=='Cast':
            # The free hand gestures while the staff arm retains its source
            # local pose. Torso motion still carries the supporting shoulder.
            baseline=humanoid.Pose(body,clips['Idle'])
            for track in clips[label]['tracks']:
                if track['name'] not in ['bip01 r clavicle','bip01 r upperarm','bip01 r forearm','bip01 r hand']:continue
                index=baseline.names[track['name']]
                for channel,value in [('translation',baseline.positions[index]),('rotation',baseline.rotations[index])]:track[channel]['values']=[list(value) for _ in track[channel]['times']]
        authored[label]='Authored '+label+' on measured source limbs with distributed torso motion, planted foot targets and retained wrist hierarchy; Cast supports the staff arm. Not recovered original Lich choreography.'
    return True
