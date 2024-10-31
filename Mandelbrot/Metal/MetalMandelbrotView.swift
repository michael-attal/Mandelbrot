//
//  MetalMandelbrotView.swift
//  Mandelbrot
//
//  Created by Michaël ATTAL on 31/10/2024.
//

import MetalKit
import SwiftUI

struct MetalMandelbrotView: NSViewRepresentable {
    @State private var zoom: CGFloat = 1.0
    @State private var panOffset: CGSize = .zero

    func makeCoordinator() -> Coordinator {
        Coordinator(zoom: $zoom, panOffset: $panOffset)
    }

    func makeNSView(context: Context) -> MTKView {
        guard let metalDevice = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal is not supported on this device")
        }

        // Use the custom ZoomableMTKView
        let mtkView = ZoomableMTKView(frame: .zero, device: metalDevice)
        mtkView.coordinator = context.coordinator
        mtkView.delegate = context.coordinator
        mtkView.enableSetNeedsDisplay = true
        mtkView.isPaused = false

        // Add gesture recognizers
        let pinchRecognizer = NSMagnificationGestureRecognizer(target: context.coordinator, action: #selector(context.coordinator.handleMagnification(_:)))
        mtkView.addGestureRecognizer(pinchRecognizer)

        let panRecognizer = NSPanGestureRecognizer(target: context.coordinator, action: #selector(context.coordinator.handlePan(_:)))
        mtkView.addGestureRecognizer(panRecognizer)

        return mtkView
    }

    func updateNSView(_ nsView: MTKView, context: Context) {}

    class Coordinator: NSObject, MTKViewDelegate {
        var metalDevice: MTLDevice!
        var metalCommandQueue: MTLCommandQueue!
        var pipelineState: MTLRenderPipelineState!
        var uniformsBuffer: MTLBuffer!

        @Binding var zoom: CGFloat
        @Binding var panOffset: CGSize

        struct Uniforms {
            var cmin: SIMD2<Float>
            var cmax: SIMD2<Float>
            var maxIterations: Int32
            var padding: UInt32 = 0
        }

        var baseCmin = SIMD2<Float>(-2.0, -1.5)
        var baseCmax = SIMD2<Float>(1.0, 1.5)
        var uniforms: Uniforms

        init(zoom: Binding<CGFloat>, panOffset: Binding<CGSize>) {
            self._zoom = zoom
            self._panOffset = panOffset
            self.uniforms = Uniforms(
                cmin: baseCmin,
                cmax: baseCmax,
                maxIterations: 256
            )
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
            uniformsBuffer = metalDevice.makeBuffer(length: MemoryLayout<Uniforms>.size, options: [])
        }

        func updateUniformsBuffer(viewSize: CGSize) {
            let aspectRatio = Float(viewSize.width / viewSize.height)

            // Calculate the new width and height based on the zoom level
            let width = (baseCmax.x - baseCmin.x) / Float(zoom)
            let height = (baseCmax.y - baseCmin.y) / Float(zoom)

            // Apply aspect ratio correction
            var adjustedWidth = width
            var adjustedHeight = height
            if aspectRatio > 1 {
                adjustedWidth = width * aspectRatio
            } else {
                adjustedHeight = height / aspectRatio
            }

            // Calculate the center point with panning
            let centerX = (baseCmin.x + baseCmax.x) / 2.0 - Float(panOffset.width) * adjustedWidth
            let centerY = (baseCmin.y + baseCmax.y) / 2.0 + Float(panOffset.height) * adjustedHeight

            uniforms.cmin = SIMD2<Float>(centerX - adjustedWidth / 2.0, centerY - adjustedHeight / 2.0)
            uniforms.cmax = SIMD2<Float>(centerX + adjustedWidth / 2.0, centerY + adjustedHeight / 2.0)

            let bufferPointer = uniformsBuffer.contents()
            memcpy(bufferPointer, &uniforms, MemoryLayout<Uniforms>.size)
        }

        func draw(in view: MTKView) {
            guard let drawable = view.currentDrawable,
                  let renderPassDescriptor = view.currentRenderPassDescriptor else { return }

            updateUniformsBuffer(viewSize: view.drawableSize)

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

        // Shared zoom handling method
        func zoom(at locationInView: CGPoint, in view: NSView, with zoomFactor: CGFloat) {
            let viewSize = view.bounds.size

            // Normalize the cursor position to (-1, 1) range
            let normalizedX = (locationInView.x / viewSize.width) * 2 - 1
            let normalizedY = (locationInView.y / viewSize.height) * 2 - 1

            // Adjust for coordinate system
            let adjustedY = -normalizedY

            // Convert to complex plane coordinates
            let aspectRatio = Float(viewSize.width / viewSize.height)
            let width = (baseCmax.x - baseCmin.x) / Float(zoom)
            let height = (baseCmax.y - baseCmin.y) / Float(zoom)
            var adjustedWidth = width
            var adjustedHeight = height
            if aspectRatio > 1 {
                adjustedWidth = width * aspectRatio
            } else {
                adjustedHeight = height / aspectRatio
            }

            let centerX = (baseCmin.x + baseCmax.x) / 2.0 - Float(panOffset.width) * adjustedWidth
            let centerY = (baseCmin.y + baseCmax.y) / 2.0 + Float(panOffset.height) * adjustedHeight

            let cursorComplexX = centerX + Float(normalizedX) * adjustedWidth / 2.0
            let cursorComplexY = centerY + Float(adjustedY) * adjustedHeight / 2.0

            // Update the zoom level
            zoom *= zoomFactor

            // Calculate the new adjusted width and height
            let newWidth = (baseCmax.x - baseCmin.x) / Float(zoom)
            let newHeight = (baseCmax.y - baseCmin.y) / Float(zoom)
            var newAdjustedWidth = newWidth
            var newAdjustedHeight = newHeight
            if aspectRatio > 1 {
                newAdjustedWidth = newWidth * aspectRatio
            } else {
                newAdjustedHeight = newHeight / aspectRatio
            }

            // Calculate the new center so that the cursor stays in the same place
            let newCenterX = cursorComplexX - Float(normalizedX) * newAdjustedWidth / 2.0
            let newCenterY = cursorComplexY - Float(adjustedY) * newAdjustedHeight / 2.0

            // Update panOffset based on the new center
            panOffset.width = CGFloat(((baseCmin.x + baseCmax.x) / 2.0 - newCenterX) / newAdjustedWidth)
            panOffset.height = CGFloat((newCenterY - (baseCmin.y + baseCmax.y) / 2.0) / newAdjustedHeight)
        }

        // Gesture handling methods
        @objc func handleMagnification(_ sender: NSMagnificationGestureRecognizer) {
            if sender.state == .changed {
                guard let view = sender.view else { return }
                let locationInView = sender.location(in: view)

                // Compute the zoom factor
                let zoomFactor = 1 + sender.magnification
                sender.magnification = 0 // Reset magnification

                // Use the shared zoom method
                zoom(at: locationInView, in: view, with: zoomFactor)
            }
        }

        @objc func handlePan(_ sender: NSPanGestureRecognizer) {
            let translation = sender.translation(in: sender.view)
            let viewSize = sender.view?.bounds.size ?? CGSize(width: 1, height: 1)

            // Update panOffset based on the translation and view size
            panOffset.width += translation.x / viewSize.width
            panOffset.height -= translation.y / viewSize.height

            sender.setTranslation(.zero, in: sender.view)
        }

        // Method to handle scroll wheel events
        func handleScrollWheel(_ event: NSEvent) {
            guard let view = event.window?.contentView else { return }

            // Get the location of the cursor in view coordinates
            let locationInView = view.convert(event.locationInWindow, from: nil)

            // Compute the zoom factor
            let scrollSensitivity: CGFloat = 0.01
            let zoomFactor = 1 + event.deltaY * scrollSensitivity

            // Use the shared zoom method
            zoom(at: locationInView, in: view, with: zoomFactor)
        }
    }

    // Custom MTKView subclass to handle scroll wheel events
    class ZoomableMTKView: MTKView {
        weak var coordinator: Coordinator?

        override func scrollWheel(with event: NSEvent) {
            coordinator?.handleScrollWheel(event)
        }
    }
}
