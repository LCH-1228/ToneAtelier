//
//  ContentView.swift
//  ToneAtelier
//
//  Created by LCH on 4/22/26.
//

import ComposableArchitecture
import SwiftUI

struct ContentView: View {
  private let appRootStore = Store(initialState: AppRootFeature.State()) {
    AppRootFeature()
  }

  var body: some View {
    AppRootView(store: appRootStore)
  }
}

#Preview {
  ContentView()
}
