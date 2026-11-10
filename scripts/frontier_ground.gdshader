shader_type canvas_item;
render_mode unshaded;
uniform sampler2D terrain_materials : source_color, filter_linear;
uniform sampler2D water_materials : source_color, filter_linear, repeat_enable;
uniform vec2 world_size=vec2(8192.0,5120.0);
uniform vec2 groves[14];
uniform vec2 cliffs[3];
uniform vec2 road[6];
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1)),f.x),f.y);}
vec3 material(vec2 p,vec2 tile){vec2 uv=fract(p/480.0)*0.472+0.014+tile*0.5;return texture(terrain_materials,uv).rgb;}
float segment(vec2 p,vec2 a,vec2 b){vec2 v=b-a;return length(p-a-v*clamp(dot(p-a,v)/dot(v,v),0.0,1.0));}
void fragment(){
 vec2 p=UV*world_size;
 float n=noise(p/180.0);
 vec3 grass=material(p,vec2(0));
 vec3 forest=material(p,vec2(1,1));
 float woods=0.0;
 for(int i=0;i<14;i++){woods=max(woods,1.0-smoothstep(170.0,600.0,distance(p,groves[i])+n*90.0));}
 vec3 color=mix(grass,forest,woods*0.75);
 float d=100000.0;
 for(int i=0;i<5;i++){d=min(d,segment(p,road[i],road[i+1]));}
 float track=1.0-smoothstep(66.0+n*16.0,100.0+n*22.0,d);
 color=mix(color,material(p,vec2(1,0))*vec3(1.12,1.08,0.95),track*0.92);
 float stone=0.0;
 for(int i=0;i<3;i++){stone=max(stone,1.0-smoothstep(0.75,1.25,length((p-cliffs[i])/vec2(370,210))+n*0.12));}
 color=mix(color,material(p,vec2(0,1)),stone);
 float shore=length((p-vec2(6500,1600))/vec2(950,520));
 float wet=1.0-smoothstep(0.98,1.13,shore+n*0.02);
 color=mix(color,material(p,vec2(1,0))*vec3(0.75,0.81,0.67),wet);
 float water=1.0-smoothstep(0.96,1.0,shore+n*0.025);
 vec3 lake=texture(water_materials,p/750.0).rgb*vec3(0.9,0.98,0.88);
 color=mix(color,lake,water);
 float warmth=noise(p/1100.0)*0.1+0.92;
 COLOR=vec4(color*vec3(1.04,1.03,0.91)*warmth,1.0);
}
