shader_type canvas_item;
render_mode unshaded;
uniform float motion_rate=1.0;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1)),f.x),f.y);}
void fragment(){
 vec2 p=UV*vec2(2100,1240)+vec2(5450,980);
 float edge=length((p-vec2(6500,1600))/vec2(950,520))+noise(p/180.0)*0.025;
 float alpha=1.0-smoothstep(0.95,1.01,edge);
 vec2 drift=vec2(TIME*0.003,TIME*0.0015)*motion_rate;
 vec3 a=texture(TEXTURE,fract(p/750.0+drift)).rgb;
 vec3 b=texture(TEXTURE,fract(p/520.0-drift*0.6)).rgb;
 COLOR=vec4(mix(a,b,0.28)*vec3(0.9,0.98,0.88),alpha);
}
