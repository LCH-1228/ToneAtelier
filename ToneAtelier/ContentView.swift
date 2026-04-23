//
//  ContentView.swift
//  ToneAtelier
//
//  Created by LCH on 4/22/26.
//

import ComposableArchitecture
import SwiftUI

struct ContentView: View {
  private let loginStore = Store(initialState: LoginFeature.State()) {
    LoginFeature()
  }

  var body: some View {
    NavigationStack {
      LoginView(store: loginStore)
    }
  }
}

#Preview {
  ContentView()
}
