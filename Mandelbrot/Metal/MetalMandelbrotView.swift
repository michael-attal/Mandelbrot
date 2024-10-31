//
//  MetalMandelbrotView.swift
//  Mandelbrot
//
//  Created by Michaël ATTAL on 31/10/2024.
//

import MetalKit
import SwiftUI

struct MetalMandelbrotView: NSViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> MTKView {
        guard let metalDevice = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal is not supported on this device")
        }

        // Create and configure the MTKView
        let mtkView = MTKView(frame: .zero, device: metalDevice)
        mtkView.delegate = context.coordinator
        mtkView.enableSetNeedsDisplay = true
        mtkView.isPaused = false
        return mtkView
    }

    func updateNSView(_ nsView: MTKView, context: Context) {}

    class Coordinator: NSObject, MTKViewDelegate {
        var metalDevice: MTLDevice!
        var metalCommandQueue: MTLCommandQueue!
        var pipelineState: MTLRenderPipelineState!
        var uniformsBuffer: MTLBuffer!

        struct Uniforms {
            var cmin: SIMD2<Float>
            var cmax: SIMD2<Float>
            var maxIterations: Int32
            var padding: UInt32 = 0 // Padding to match Metal's alignment
        }

        var uniforms = Uniforms(
            cmin: SIMD2<Float>(-2.0, -1.5),
            cmax: SIMD2<Float>(1.0, 1.5),
            maxIterations: 256
        )

        override init() {
            super.init()
            setupMetal()
            createPipelineState()
            createUniformsBuffer()
        }

        func setupMetal() {
            metalDevice = MTLCreateSystemDefaultDevice()
            metalCommandQueue = metalDevice.makeCommandQueue()
        }

        func createPipelineState() {
            let defaultLibrary = metalDevice.makeDefaultLibrary()
            let vertexFunction = defaultLibrary?.makeFunction(name: "vertexShader")
            let fragmentFunction = defaultLibrary?.makeFunction(name: "fragmentShader")

            let pipelineStateDescriptor = MTLRenderPipelineDescriptor()
            pipelineStateDescriptor.label = "Mandelbrot Pipeline"
            pipelineStateDescriptor.vertexFunction = vertexFunction
            pipelineStateDescriptor.fragmentFunction = fragmentFunction
            pipelineStateDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

            do {
                pipelineState = try metalDevice.makeRenderPipelineState(descriptor: pipelineStateDescriptor)
            } catch {
                fatalError("Failed to create pipeline state: \(error)")
            }
        }

        func createUniformsBuffer() {
            uniformsBuffer = metalDevice.makeBuffer(bytes: &uniforms,
                                                    length: MemoryLayout<Uniforms>.size,
                                                    options: [])
        }

        func draw(in view: MTKView) {
            guard let drawable = view.currentDrawable,
                  let renderPassDescriptor = view.currentRenderPassDescriptor else { return }

            let commandBuffer = metalCommandQueue.makeCommandBuffer()!

            let commandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
            commandEncoder.setRenderPipelineState(pipelineState)

            // Set the uniforms buffer
            commandEncoder.setFragmentBuffer(uniformsBuffer, offset: 0, index: 0)

            // Draw a full-screen quad
            commandEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)

            commandEncoder.endEncoding()

            commandBuffer.present(drawable)
            commandBuffer.commit()
        }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
    }
}
