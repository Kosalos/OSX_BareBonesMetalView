#pragma once
#include <simd/simd.h>

struct Control {
    int xSize,ySize;
    int colorScroll;
    
    vector_float2 ulCorner;
    float zoom, realScale, imagScale;
};

