//
//  GlassEffectCompatible.swift
//  ToneAtelier
//
//  Created by Codex on 5/20/26.
//

import SwiftUI

enum GlassEffectVariant {
  case regular
  case regularInteractive
}

extension View {
  @ViewBuilder
  func glassEffectCompatible(
    _ variant: GlassEffectVariant = .regular,
    in shape: some Shape
  ) -> some View {
    if #available(iOS 26.0, *) {
      applyGlassEffect(variant: variant, in: shape)
    } else {
      background(.ultraThinMaterial, in: shape)
    }
  }
}

@available(iOS 26.0, *)
private extension View {
  @ViewBuilder
  func applyGlassEffect(variant: GlassEffectVariant, in shape: some Shape) -> some View {
    switch variant {
    case .regular:
      glassEffect(.regular, in: shape)
    case .regularInteractive:
      glassEffect(.regular.interactive(), in: shape)
    }
  }
}
