//
//  Shaders.metal
//  Mandelbrot
//
//  Created by Michaël ATTAL on 31/10/2024.
//

#include <metal_stdlib>
using namespace metal;

struct Uniforms {
    float2 cmin;
    float2 cmax;
    int maxIterations;
    uint padding;
};

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

// Helper function to convert HSV to RGB
float3 hsv2rgb(float3 c) {
    float4 K = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    float3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

vertex VertexOut vertexShader(uint vertexID [[vertex_id]]) {
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
                               constant Uniforms& uniforms [[buffer(0)]]) {
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

    // Map the number of iterations to a color using HSV color space
    float hue = float(i) / float(maxIterations);
    float saturation = 1.0;
    float value = i < maxIterations ? 1.0 : 0.0; // Black inside the set

    float3 color = hsv2rgb(float3(hue, saturation, value));
    return float4(color, 1.0);
}
