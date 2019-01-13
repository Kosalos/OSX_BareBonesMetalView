#include <metal_stdlib>
#include "Shader.h"

using namespace metal;

constant int MaxIterations = 256;
constant float pi = 3.141592654;

kernel void juliaShader
(
 texture2d<float, access::write> outTexture [[texture(0)]],
 constant Control &control [[buffer(0)]],
 constant float3 *color    [[buffer(1)]],    // color lookup table[256]
 uint2 p [[thread_position_in_grid]]
 )
{
    if(int(p.x) >= control.xSize || int(p.y) >= control.ySize) return;
    
    float2 pp = float2(p);
    
    // 0 = normal; else amount of radial symetry
    if(control.radialAmount > 0) {
        float2 center = float2(float(control.xSize)/2, float(control.ySize)/2);
        float2 delta = pp - center;
        float angle = fabs( atan2(delta.y,delta.x) );
        
        float dRatio = 0.01 + control.radialAmount * pi;
        while(angle > dRatio) angle -= dRatio;
        if(angle > dRatio/2) angle = dRatio - angle;
        
        float dist = length(delta);
        
        pp.x = center.x + cos(angle) * dist;
        pp.y = center.y + sin(angle) * dist;
    }
    
    float real = control.ulCorner.x + pp.x / control.zoom;
    float imag = control.ulCorner.y + pp.y / control.zoom;
    int iter = 0;
    
    for(; iter < MaxIterations; ++iter) {
        if(real * real + imag * imag > 4.0) break;
        
        float _r = real;
        real = real * real - imag * imag + control.realScale;
        imag = 2 * _r * imag + control.imagScale;
    }
    
    int cIndex = (iter * 4 + control.colorScroll) % 256;
    outTexture.write(float4(color[cIndex],1), p);
}
