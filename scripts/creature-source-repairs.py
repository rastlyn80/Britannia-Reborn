"""Explicit local-art repairs; the source archive and strict reader stay intact."""
import collections
import math
import struct


def neighbour_weights(model, vertex):
    adjacent=sorted({i for face in model['polygons'] if vertex in face[:3] for i in face[:3]}-{vertex})
    if len(adjacent)<2:
        raise ValueError('An unweighted vertex needs at least two surface neighbours')
    scores=collections.defaultdict(float)
    for other in adjacent:
        pairs=model['weights'][other]
        if abs(sum(w for _,w in pairs)-1.)>.001:
            raise ValueError('Repair must not propagate unweighted neighbours')
        distance=max(1e-8,math.dist(model['points'][vertex],model['points'][other]))
        for bone,weight in pairs:
            scores[bone]+=weight/distance
    chosen=sorted(scores.items(),key=lambda row:(-row[1],row[0]))[:4]
    total=sum(weight for _,weight in chosen)
    if not math.isfinite(total) or total<=0.:
        raise ValueError('No finite neighbouring skin influence')
    return [(bone,weight/total) for bone,weight in chosen],adjacent


def repair_one_unweighted_vertex(raw, reader):
    buffers=[payload for tag,payload,_ in reader.chunks(raw) if tag==0xca5e0702]
    reader.require(len(buffers)==1,'One skin buffer required for the explicit repair')
    payload=buffers[0]
    reader.require(len(payload)>=12 and raw.count(payload)==1,'Ambiguous or truncated skin buffer')
    count=struct.unpack_from('<I',payload)[0];pos=12;bad=[];patched=bytearray(raw)
    reader.require(count<=len(payload)//4,'Unbounded skin count')
    for vertex in range(count):
        reader.require(pos+4<=len(payload),'Truncated influence count')
        n=struct.unpack_from('<I',payload,pos)[0];pos+=4
        reader.require(0<n<=4 and pos+n*8<=len(payload),'Invalid influence bounds')
        pairs=[struct.unpack_from('<If',payload,pos+j*8) for j in range(n)]
        reader.require(all(math.isfinite(w) and w>=0. for _,w in pairs),'Invalid skin influence')
        total=sum(w for _,w in pairs)
        if total==0.:
            bad.append(vertex)
            # A temporary valid weight permits the unchanged strict reader to
            # inspect the mesh. The returned model receives surface neighbours.
            struct.pack_into('<f',patched,raw.index(payload)+pos+4,1.)
        else:
            reader.require(abs(total-1.)<.001,'Only a completely unweighted vertex may be repaired')
        pos+=n*8
    reader.require(pos==len(payload) and len(bad)==1,'Repair is restricted to exactly one unweighted vertex')
    model=reader.parse(bytes(patched),scene_root_names=True)
    vertex=bad[0];replacement,adjacent=neighbour_weights(model,vertex)
    model['weights'][vertex]=replacement
    return model,{'vertex':vertex,'neighbours':adjacent,'replacement_weights':replacement,
                  'method':'Authored inverse-distance interpolation from directly adjacent source vertices, bounded to four normalised influences; not a recovered original weight. All visible geometry, UVs and rig data retained.'}
