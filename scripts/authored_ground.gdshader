shader_type canvas_item;
render_mode unshaded;
uniform sampler2D micro_materials : source_color, filter_linear;
uniform sampler2D water_mask : filter_linear;
uniform sampler2D surface_mask : filter_linear;
uniform vec2 world_size=vec2(8192.0,5120.0);
vec3 material_at(vec2 p,vec2 cell){return texture(micro_materials,fract(p/440.0)*0.47+vec2(0.015)+cell*0.5).rgb;}
void fragment(){
 vec2 p=UV*world_size;
 vec3 macro=texture(TEXTURE,UV).rgb;
 vec4 masks=texture(surface_mask,UV);
 vec3 grass=material_at(p,vec2(0,0));
 vec3 soil=material_at(p,vec2(1,0));
 vec3 gravel=material_at(p,vec2(0,1));
 vec3 litter=material_at(p,vec2(1,1));
 float noise=dot(grass,vec3(0.299,0.587,0.114));
 float road=clamp(masks.r+(noise-0.4)*0.2,0.0,1.0);
 vec3 meadow=grass*mix(vec3(1.02,1.02,0.92),vec3(1.16,0.98,0.7),masks.a);
 meadow=mix(meadow,mix(grass,litter,0.28)*vec3(0.86,0.98,0.87),masks.b*0.45);
 vec3 trail=mix(soil,gravel,0.34)*vec3(1.08,1.04,0.88);
 vec3 color=mix(meadow,trail,road*0.93);
 color=mix(color,gravel*vec3(0.86,0.86,0.77),masks.g*0.9);
 // The authored painting controls broad colour and geography; detail stays crisp.
 color=mix(color,macro,0.19);
 float water=texture(water_mask,UV).r;
 color=mix(color,macro,smoothstep(0.08,0.85,water));
 COLOR=vec4(color,1.0);
}
