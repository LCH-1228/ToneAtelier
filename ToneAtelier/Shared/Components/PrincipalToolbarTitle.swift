//
//  PrincipalToolbarTitle.swift
//  ToneAtelier
//
//  Created by Codex on 5/6/26.
//

import SwiftUI

struct PrincipalToolbarTitle: ToolbarContent {
  let title: String

  init(_ title: String) {
    self.title = title
  }

  var body: some ToolbarContent {
    ToolbarItem(placement: .principal) {
      Text(title)
        .mulgyeol(.bodyNormal)
        .foregroundStyle(AppTheme.gray60)
    }
  }
}
