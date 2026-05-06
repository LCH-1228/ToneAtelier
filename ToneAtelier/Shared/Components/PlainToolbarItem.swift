//
//  PlainToolbarItem.swift
//  ToneAtelier
//
//  Created by Codex on 5/6/26.
//

import SwiftUI

struct PlainToolbarItem<Content: View>: ToolbarContent {
  let placement: ToolbarItemPlacement
  let content: () -> Content

  init(
    placement: ToolbarItemPlacement,
    @ViewBuilder content: @escaping () -> Content
  ) {
    self.placement = placement
    self.content = content
  }

  var body: some ToolbarContent {
    ToolbarItem(placement: placement) {
      content()
    }
    .sharedBackgroundVisibility(.hidden)
  }
}
