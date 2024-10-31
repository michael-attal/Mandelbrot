//
//  MandelbrotApp.swift
//  Mandelbrot
//
//  Created by Michaël ATTAL on 31/10/2024.
//

import SwiftData
import SwiftUI

@main
struct MandelbrotApp: App {
    var body: some Scene {
        WindowGroup {
            MetalMandelbrotView()
                .frame(minWidth: 800, minHeight: 600)
        }
    }
}
