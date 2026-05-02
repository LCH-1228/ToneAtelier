//
//  ToneAtelierApp.swift
//  ToneAtelier
//
//  Created by LCH on 4/22/26.
//

import ComposableArchitecture
import KakaoSDKAuth
import KakaoSDKCommon
import FirebaseCore
import FirebaseMessaging
import OSLog
import SwiftUI
import iamport_ios

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    FirebaseApp.configure()

    Messaging.messaging().delegate = self
    UNUserNotificationCenter.current().delegate = self

    Task {
      do {
        _ = try await UNUserNotificationCenter.current()
          .requestAuthorization(options: [.alert, .badge, .sound])
      } catch {
        Logger.push.error("Push authorization failed: \(error.localizedDescription, privacy: .private)")
      }
    }

    // APNS 디바이스 토큰은 사용자 권한과 무관하게 발급되므로, 권한 응답을 기다리지 않고 등록한다.
    application.registerForRemoteNotifications()

    return true
  }

  func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    Messaging.messaging().apnsToken = deviceToken
  }

  func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    Logger.push.error("APNS register failed: \(error.localizedDescription, privacy: .private)")
  }

  func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
    guard let fcmToken else { return }
    // 서버 PUT 호출은 AppRootFeature가 tokenUpdates 스트림을 구독해 인증 세션이 있을 때만 수행한다.
    @Dependency(\.pushTokenClient) var pushTokenClient
    let client = pushTokenClient
    Task {
      await client.update(fcmToken)
      Logger.push.notice("FCM token cached")
    }
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([.banner, .list, .sound, .badge])
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    Logger.push.notice("Push tapped")
    completionHandler()
  }
}

@main
struct ToneAtelierApp: App {

  @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

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
          if url.scheme == AppURLScheme.payment {
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
