//
//  ToneAtelierApp.swift
//  ToneAtelier
//
//  Created by LCH on 4/22/26.
//

import KakaoSDKAuth
import KakaoSDKCommon
import SwiftUI
import iamport_ios

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
          // 아임포트 결제 후 외부 카드앱(ISP 등)에서 복귀한 경우 SDK에 결과 전달.
          if url.scheme == "mitti-toneatelier" {
            Iamport.shared.receivedURL(url)
            return
          }

          guard KakaoSDKConfiguration.isConfigured else { return }

          if AuthApi.isKakaoTalkLoginUrl(url) {
            _ = AuthController.handleOpenUrl(url: url)
          }
        }
    }
  }
}
