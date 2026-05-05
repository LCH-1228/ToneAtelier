//
//  VideoRoutePickerButton.swift
//  ToneAtelier
//
//  Created by Codex on 5/5/26.
//

import AVKit
import SwiftUI
import UIKit

struct VideoRoutePickerButton: UIViewRepresentable {
  let tintColor: UIColor

  func makeUIView(context: Context) -> AVRoutePickerView {
    let view = AVRoutePickerView()
    view.tintColor = tintColor
    view.activeTintColor = tintColor
    view.prioritizesVideoDevices = true
    view.backgroundColor = .clear
    return view
  }

  func updateUIView(_ uiView: AVRoutePickerView, context: Context) {
    uiView.tintColor = tintColor
    uiView.activeTintColor = tintColor
  }
}
