"""Resolve each mesh's local skin indices to the original Granny joint table."""

import struct


def mesh_palettes(raw, reader):
    palettes = {}
    skins = []
    offset = 0
    for tag, payload, ancestors in reader.chunks(raw):
        if tag == 0xCA5E0C03 and ancestors[-1:] == [0xCA5E0C06]:
            palette_id, = struct.unpack('<I', payload)
            assert palette_id not in palettes
            palettes[palette_id] = (offset, [])
        elif tag == 0xCA5E0C0A:
            assert ancestors[-2:] == [0xCA5E0C03, 0xCA5E0C09]
            palettes[palette_id][1].append(struct.unpack_from('<I', payload)[0])
            offset += 1
        elif tag == 0xCA5E0702:
            assert ancestors[-1:] == [0xCA5E0601]
            skins.append(struct.unpack_from('<3I', payload))
    assert sorted(palettes) == list(range(1, len(skins) + 1))
    assert all(len(palettes[i][1]) == (last + 1 if points else 1)
               for i, (points, last, _) in enumerate(skins, 1))
    return palettes, skins
