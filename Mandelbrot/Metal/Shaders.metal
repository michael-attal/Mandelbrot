//
//  Shaders.metal
//  Mandelbrot
//
//  Created by Michaël ATTAL on 31/10/2024.
//

#include <metal_stdlib>
using namespace metal;

struct Uniforms {
    float2 cmin;          // 8 bytes
    float2 cmax;          // 8 bytes
    int maxIterations;    // 4 bytes
    uint padding;         // 4 bytes padding to match alignment
};

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

vertex VertexOut vertexShader(uint vertexID [[ vertex_id ]]) {
    // Positions of the full-screen quad
    float4 positions[4] = {
        float4(-1.0, -1.0, 0.0, 1.0),
        float4(-1.0,  1.0, 0.0, 1.0),
        float4( 1.0, -1.0, 0.0, 1.0),
        float4( 1.0,  1.0, 0.0, 1.0)
    };

    float2 texCoords[4] = {
        float2(0.0, 0.0),
        float2(0.0, 1.0),
        float2(1.0, 0.0),
        float2(1.0, 1.0)
    };

    VertexOut out;
    out.position = positions[vertexID];
    out.texCoord = texCoords[vertexID];
    return out;
}

fragment float4 fragmentShader(VertexOut in [[stage_in]],
                               constant Uniforms& uniforms [[ buffer(0) ]]) {
    float2 uv = in.texCoord;

    // Convert texture coordinates to complex plane coordinates
    float2 c = uniforms.cmin + uv * (uniforms.cmax - uniforms.cmin);

    // Mandelbrot iteration
    float2 z = float2(0.0, 0.0);
    int maxIterations = uniforms.maxIterations;
    int i;
    for (i = 0; i < maxIterations; i++) {
        float x = z.x * z.x - z.y * z.y + c.x;
        float y = 2.0 * z.x * z.y + c.y;
        z = float2(x, y);
        if (dot(z, z) > 4.0) break;
    }

    // Map the number of iterations to a grayscale color
    float color = float(i) / float(maxIterations);
    return float4(color, color, color, 1.0);
}
