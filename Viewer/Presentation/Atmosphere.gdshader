shader_type sky;
// All weather/time controls come from the connected server. TIME animates only clouds.
uniform vec3 zenith : source_color = vec3(0.16,0.38,0.62);
uniform vec3 horizon : source_color = vec3(0.75,0.83,0.85);
uniform vec3 sunlight : source_color = vec3(1.0,0.86,0.65);
uniform vec3 sun_direction = vec3(0.3,0.65,0.4);
uniform float daylight = 1.0;
uniform float cloud_cover = 0.30;
uniform float storm = 0.0;
uniform float cloud_clock = 0.0;
uniform sampler2D cloud_noise : filter_linear_mipmap, repeat_enable;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
void sky() {
 float elevation=max(EYEDIR.y,0.0);
 vec3 color=mix(horizon,zenith,pow(elevation,0.45));
 float alignment=max(dot(EYEDIR,normalize(sun_direction)),0.0);
 color+=sunlight*pow(alignment,24.0)*0.20*daylight;
 color+=sunlight*smoothstep(0.99975,0.9999,alignment)*3.0*daylight;
 vec2 plane=EYEDIR.xz/(0.20+elevation)*2.8;
 plane+=vec2(cloud_clock*0.0018,cloud_clock*0.0007);
 float n=texture(cloud_noise,plane*0.10).r;
 float clouds=smoothstep(0.72-cloud_cover*0.45,0.94-cloud_cover*0.45,n);
 clouds*=smoothstep(0.005,0.15,elevation);
 vec3 cloud_color=mix(vec3(0.92,0.94,0.95),vec3(0.24,0.29,0.36),storm);
 cloud_color*=mix(0.10,1.0,daylight)*mix(0.78,1.0,n);
 color=mix(color,cloud_color,clouds*0.92);
 float star=step(0.9987,hash(floor(EYEDIR.xz/(0.3+abs(EYEDIR.y))*850.0)));
 color+=star*(1.0-daylight)*smoothstep(0.15,0.5,elevation)*0.5*(1.0-clouds);
 if(EYEDIR.y<0.0) color=mix(horizon*0.55,color,exp(EYEDIR.y*8.0));
 COLOR=color;
}
