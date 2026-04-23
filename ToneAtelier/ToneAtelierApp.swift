//
//  ToneAtelierApp.swift
//  ToneAtelier
//
//  Created by LCH on 4/22/26.
//

import KakaoSDKAuth
import KakaoSDKCommon
import SwiftUI

@main
struct ToneAtelierApp: App {
  init() {
    if let nativeAppKey = KakaoSDKConfiguration.nativeAppKey {
      KakaoSDK.initSDK(appKey: nativeAppKey)
    }
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
        .onOpenURL { url in
          guard KakaoSDKConfiguration.isConfigured else { return }

          if AuthApi.isKakaoTalkLoginUrl(url) {
            _ = AuthController.handleOpenUrl(url: url)
          }
        }
    }
  }
}
