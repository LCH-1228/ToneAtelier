//
//  HomeDetailSectionHeader.swift
//  ToneAtelier
//
//  Created by Codex on 4/27/26.
//

import SwiftUI

struct HomeDetailSectionHeader: View {
  let leading: String
  let trailing: String

  var body: some View {
    SharedSectionHeader(leading: leading, trailing: trailing)
  }
}
