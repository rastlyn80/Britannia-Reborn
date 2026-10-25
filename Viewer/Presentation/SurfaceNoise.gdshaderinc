float surface_hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float surface_noise(vec2 p) {
 vec2 i=floor(p),f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(surface_hash(i),surface_hash(i+vec2(1,0)),f.x),mix(surface_hash(i+vec2(0,1)),surface_hash(i+vec2(1,1)),f.x),f.y);
}
float surface_fbm(vec2 p) { return surface_noise(p)*0.57+surface_noise(p*2.13+4.7)*0.28+surface_noise(p*4.31+9.1)*0.15; }
