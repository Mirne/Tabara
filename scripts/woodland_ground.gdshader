shader_type canvas_item;
render_mode unshaded;
uniform sampler2D micro_materials : source_color, filter_linear;
uniform sampler2D water_mask : filter_linear;
uniform sampler2D surface_mask : filter_linear;
uniform vec2 world_size=vec2(8192.0,5120.0);
vec2 hash2(vec2 p){return fract(sin(vec2(dot(p,vec2(127.1,311.7)),dot(p,vec2(269.5,183.3))))*43758.5453);}
vec3 sample_patch(vec2 p,vec2 tile,vec2 material){
 vec2 uv=fract(p/870.0+hash2(tile)*0.71);
 return texture(micro_materials,uv*0.45+vec2(0.025)+material*0.5).rgb;
}
vec3 material_at(vec2 p,vec2 material){
 vec2 tile=floor(p/570.0); vec2 f=smoothstep(vec2(0.0),vec2(1.0),fract(p/570.0));
 return mix(mix(sample_patch(p,tile,material),sample_patch(p,tile+vec2(1,0),material),f.x),mix(sample_patch(p,tile+vec2(0,1),material),sample_patch(p,tile+vec2(1,1),material),f.x),f.y);
}
void fragment(){
 vec2 p=UV*world_size;
 vec3 macro=texture(TEXTURE,UV).rgb;
 vec4 masks=texture(surface_mask,UV);
 vec3 grass=material_at(p,vec2(0,0));
 vec3 soil=material_at(p,vec2(1,0));
 vec3 gravel=material_at(p,vec2(0,1));
 vec3 litter=material_at(p,vec2(1,1));
 float variation=sin(p.x/430.0+sin(p.y/650.0))*sin(p.y/510.0+p.x/1250.0)*0.035;
 float luminance=dot(grass,vec3(0.299,0.587,0.114));
 vec3 meadow=mix(grass,vec3(luminance)*vec3(1.10,1.14,0.77),0.42)+variation;
 meadow=mix(meadow,mix(litter,soil,0.42)*vec3(0.81,0.88,0.67),masks.a*0.52);
 meadow=mix(meadow,meadow*vec3(0.83,0.95,0.82),masks.b*0.45);
 float road=clamp(masks.r+(luminance-0.4)*0.17,0.0,1.0);
 vec3 trail=mix(soil,gravel,0.25)*vec3(1.03,1.01,0.87);
 vec3 color=mix(meadow,trail,road*0.86);
 color=mix(color,gravel*vec3(0.87,0.91,0.80),masks.g*0.68);
 color=mix(color,macro,0.06);
 color=mix(color,macro,smoothstep(0.08,0.85,texture(water_mask,UV).r));
 COLOR=vec4(color,1.0);
}
