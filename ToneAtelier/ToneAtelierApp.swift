//
//  ToneAtelierApp.swift
//  ToneAtelier
//
//  Created by LCH on 4/22/26.
//

import ComposableArchitecture
import FirebaseCore
import FirebaseMessaging
import iamport_ios
import KakaoSDKAuth
import KakaoSDKCommon
import OSLog
import SwiftUI

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {
  static var supportedOrientations: UIInterfaceOrientationMask = .portrait

  func application(
    _ application: UIApplication,
    supportedInterfaceOrientationsFor window: UIWindow?
  ) -> UIInterfaceOrientationMask {
    Self.supportedOrientations
  }

  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
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

    if let remote = launchOptions?[.remoteNotification] as? [AnyHashable: Any],
       let roomID = remote["room_id"] as? String {
      // terminate cold launch 대응 — Task 비동기 enqueue 로는 MainTab consume 보다 늦을 수 있어
      // UserDefaults 에 동기로 즉시 저장한다.
      UserDefaults.standard.set(roomID, forKey: ChatPushClient.pendingRoomDefaultsKey)
    }

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
    let userInfo = notification.request.content.userInfo
    let pushRoomID = userInfo["room_id"] as? String
    let notificationID = notification.request.identifier

    guard let pushRoomID else {
      completionHandler([.banner, .list, .sound, .badge])
      return
    }

    @Dependency(\.chatPushClient) var chatPushClient
    @Dependency(\.chatUnreadCenter) var chatUnreadCenter
    @Dependency(\.currentChatRoomClient) var currentChatRoomClient
    let push = chatPushClient
    let unread = chatUnreadCenter
    let presence = currentChatRoomClient
    Task {
      if await presence.currentRoomID() == pushRoomID {
        // 활성 방의 푸시 — 표시·카운트 모두 생략. 알림 센터 잔존도 즉시 제거.
        UNUserNotificationCenter.current()
          .removeDeliveredNotifications(withIdentifiers: [notificationID])
        completionHandler([])
      } else {
        // dedup 은 Center 의 processedIdentifiers 가 보장. presentation 은 banner/sound 만 —
        // `.list` 를 빼서 알림 센터에 추가하지 않으려 시도하나, OS 가 잔존시킬 경우에도
        // catch-up 이 동일 ID 를 두 번 카운트하지 않는다.
        await unread.increment(pushRoomID, notificationID)
        await push.notifyReceived(pushRoomID)
        completionHandler([.banner, .sound])
      }
    }
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let userInfo = response.notification.request.content.userInfo
    guard let roomID = userInfo["room_id"] as? String else {
      completionHandler()
      return
    }

    @Dependency(\.currentChatRoomClient) var currentChatRoomClient
    @Dependency(\.chatPushClient) var chatPushClient
    let presence = currentChatRoomClient
    let push = chatPushClient
    Task {
      // 알림센터에서 같은 방의 과거 푸시를 탭하는 경우는 navigate 불필요.
      if await presence.currentRoomID() == roomID {
        completionHandler()
        return
      }
      await push.notifyTapped(roomID)
      completionHandler()
    }
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
