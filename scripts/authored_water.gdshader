shader_type canvas_item;
render_mode unshaded;
uniform sampler2D water_mask : filter_linear;
uniform float motion_rate=1.0;
void fragment(){
 float mask=texture(water_mask,UV).r;
 if(mask<0.005){discard;}
 vec3 base=texture(TEXTURE,UV).rgb;
 float ripple=sin(UV.x*840.0+UV.y*410.0+TIME*motion_rate*0.7)*sin(UV.y*620.0-TIME*motion_rate*0.5);
 COLOR=vec4(base*(1.01+ripple*0.08),mask*0.22);
}
