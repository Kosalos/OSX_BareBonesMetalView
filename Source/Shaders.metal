#include <metal_stdlib>
#include "Shader.h"

using namespace metal;

constant int MaxIterations = 256;

kernel void juliaShader
(
 texture2d<float, access::write> outTexture [[texture(0)]],
 constant Control &control [[buffer(0)]],
 constant float3 *color    [[buffer(1)]],    // color lookup table[256]
 uint2 p [[thread_position_in_grid]]
 )
{
    if(int(p.x) >= control.xSize || int(p.y) >= control.ySize) return;
    
    float real = control.ulCorner.x + float(p.x) / control.zoom;
    float imag = control.ulCorner.y + float(p.y) / control.zoom;
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
