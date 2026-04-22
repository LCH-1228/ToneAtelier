//
//  ContentView.swift
//  ToneAtelier
//
//  Created by LCH on 4/22/26.
//

import SwiftUI
import ComposableArchitecture

struct ContentView: View {
  @Dependency(\.authClient) var authClient
  @Dependency(\.userClient) var userClient
  @Dependency(\.postClient) var postClient
  @Dependency(\.filterClient) var filterClient
  @Dependency(\.chatClient) var chatClient
  @Dependency(\.commerceClient) var commerceClient
  @Dependency(\.bannerClient) var bannerClient
  @Dependency(\.notificationClient) var notificationClient
  @Dependency(\.videoClient) var videoClient
  @Dependency(\.commonClient) var commonClient

  @State private var lastResult = ""
  @State private var isLoading = false

  // MARK: - Test Parameters

  @State private var postID = ""
  @State private var filterID = ""
  @State private var userID = ""
  @State private var commentID = ""
  @State private var roomID = ""
  @State private var videoID = ""
  @State private var orderCode = ""

  @State private var testEmail = "filters@photo.com"
  @State private var testPassword = "filter1234@"
  @State private var testNick = "사진작까"

  var body: some View {
    NavigationView {
      List {
        resultSection
        parameterSection
        authSection
        userSection
        postSection
        filterSection
        chatSection
        commerceSection
        bannerSection
        notificationSection
        videoSection
        commonSection
      }
      .listStyle(.insetGrouped)
      .navigationTitle("API Tester")
    }
  }

  // MARK: - Result

  private var resultSection: some View {
    Section("Last Result") {
      if isLoading {
        ProgressView()
      }
      Text(lastResult.isEmpty ? "-" : lastResult)
        .font(.system(.caption, design: .monospaced))
        .textSelection(.enabled)
    }
  }

  // MARK: - Parameters

  private var parameterSection: some View {
    Section("Parameters") {
      TextField("postID", text: $postID)
      TextField("filterID", text: $filterID)
      TextField("userID", text: $userID)
      TextField("commentID", text: $commentID)
      TextField("roomID", text: $roomID)
      TextField("videoID", text: $videoID)
      TextField("orderCode", text: $orderCode)
      TextField("email", text: $testEmail)
      TextField("password", text: $testPassword)
      TextField("nick", text: $testNick)
    }
    .textInputAutocapitalization(.never)
    .autocorrectionDisabled()
  }

  // MARK: - Auth

  private var authSection: some View {
    Section("Auth") {
      apiButton("refresh") {
        try await authClient.refresh()
      }
    }
  }

  // MARK: - User

  private var userSection: some View {
    Section("User") {
      apiButton("validateEmail") {
        try await userClient.validateEmail(
          EmailValidationRequest(email: testEmail)
        )
      }
      apiButton("join") {
        try await userClient.join(
          JoinRequest(
            email: testEmail,
            password: testPassword,
            nick: testNick,
            name: testNick,
            introduction: nil,
            phoneNum: nil,
            hashTags: nil,
            deviceToken: nil
          )
        )
      }
      apiButton("login") {
        try await userClient.login(
          EmailLoginRequest(
            email: testEmail,
            password: testPassword,
            deviceToken: nil
          )
        )
      }
      apiButton("loginKakao") {
        try await userClient.loginKakao(
          KakaoLoginRequest(oauthToken: "test_token", deviceToken: nil)
        )
      }
      apiButton("loginApple") {
        try await userClient.loginApple(
          AppleLoginRequest(idToken: "test_token", deviceToken: nil)
        )
      }
      apiButton("logout") {
        try await userClient.logout()
      }
      apiButton("updateDeviceToken") {
        try await userClient.updateDeviceToken(
          DeviceTokenRequest(deviceToken: "test_device_token")
        )
      }
      apiButton("fetchOtherProfile") {
        try await userClient.fetchOtherProfile(userID)
      }
      apiButton("fetchMyProfile") {
        let test = try await userClient.fetchMyProfile()
        print(test)
        return test
      }
      apiButton("updateMyProfile") {
        try await userClient.updateMyProfile(
          UpdateMyProfileRequest(
            nick: testNick,
            name: nil,
            introduction: nil,
            phoneNum: nil,
          profileImage: nil,
            hashTags: nil
          )
        )
      }
      apiButton("fetchTodayAuthor") {
        try await userClient.fetchTodayAuthor()
      }
      apiButton("searchUsers") {
        try await userClient.searchUsers(testNick)
      }
    }
  }

  // MARK: - Post

  private var postSection: some View {
    Section("Post") {
      apiButton("create") {
        try await postClient.create(
          CreatePostRequest(
            category: "test",
            title: "Test Post",
            content: "Test Content",
            latitude: 37.5665,
            longitude: 126.9780,
            files: nil
          )
        )
      }
      apiButton("listGeolocation") {
        try await postClient.listGeolocation(
          GeolocationPostsQuery(
            category: nil,
            longitude: 126.9780,
            latitude: 37.5665,
            maxDistance: nil,
            limit: 10,
            next: nil,
            order_by: nil
          )
        )
      }
      apiButton("search") {
        try await postClient.search("test")
      }
      apiButton("detail") {
        try await postClient.detail(postID)
      }
      apiButton("update") {
        try await postClient.update(
          postID,
          UpdatePostRequest(
            category: nil,
            title: "Updated Title",
            content: nil,
            latitude: nil,
            longitude: nil,
            files: nil
          )
        )
      }
      apiButton("delete") {
        try await postClient.delete(postID)
      }
      apiButton("setLike (true)") {
        try await postClient.setLike(postID, true)
      }
      apiButton("userPosts") {
        try await postClient.userPosts(
          userID,
          UserPostListQuery(category: nil, limit: 10, next: nil)
        )
      }
      apiButton("likedPosts") {
        try await postClient.likedPosts(
          UserPostListQuery(category: nil, limit: 10, next: nil)
        )
      }
      apiButton("createComment") {
        try await postClient.createComment(
          postID,
          CommentWriteRequest(parent_comment_id: nil, content: "Test comment")
        )
      }
      apiButton("updateComment") {
        try await postClient.updateComment(
          postID,
          commentID,
          CommentEditRequest(content: "Edited comment")
        )
      }
      apiButton("deleteComment") {
        try await postClient.deleteComment(postID, commentID)
      }
    }
  }

  // MARK: - Filter

  private var filterSection: some View {
    Section("Filter") {
      apiButton("create") {
        try await filterClient.create(
          CreateFilterRequest(
            category: "test",
            title: "Test Filter",
            price: 0,
            description: "Test filter description",
            files: [],
            photo_metadata: nil,
            filter_values: .object([:])
          )
        )
      }
      apiButton("list") {
        try await filterClient.list(
          FilterListQuery(next: nil, limit: 10, category: nil, order_by: nil)
        )
      }
      apiButton("detail") {
        try await filterClient.detail(filterID)
      }
      apiButton("update") {
        try await filterClient.update(
          filterID,
          UpdateFilterRequest(
            category: nil,
            title: "Updated Filter",
            price: nil,
            description: nil,
            files: nil,
            photo_metadata: nil,
            filter_values: nil
          )
        )
      }
      apiButton("delete") {
        try await filterClient.delete(filterID)
      }
      apiButton("setLike (true)") {
        try await filterClient.setLike(filterID, true)
      }
      apiButton("userFilters") {
        try await filterClient.userFilters(
          userID,
          UserFilterListQuery(next: nil, limit: 10, category: nil)
        )
      }
      apiButton("likedFilters") {
        try await filterClient.likedFilters(
          UserFilterListQuery(next: nil, limit: 10, category: nil)
        )
      }
      apiButton("hotTrend") {
        try await filterClient.hotTrend()
      }
      apiButton("todayFilter") {
        try await filterClient.todayFilter()
      }
      apiButton("createComment") {
        try await filterClient.createComment(
          filterID,
          CommentWriteRequest(parent_comment_id: nil, content: "Test comment")
        )
      }
      apiButton("updateComment") {
        try await filterClient.updateComment(
          filterID,
          commentID,
          CommentEditRequest(content: "Edited comment")
        )
      }
      apiButton("deleteComment") {
        try await filterClient.deleteComment(filterID, commentID)
      }
    }
  }

  // MARK: - Chat

  private var chatSection: some View {
    Section("Chat") {
      apiButton("createRoom") {
        try await chatClient.createRoom(
          CreateChatRoomRequest(opponent_id: userID)
        )
      }
      apiButton("listRooms") {
        try await chatClient.listRooms()
      }
      apiButton("sendMessage") {
        try await chatClient.sendMessage(
          roomID,
          SendChatRequest(content: "Test message", files: nil)
        )
      }
      apiButton("listMessages") {
        try await chatClient.listMessages(
          roomID,
          ChatHistoryQuery(next: nil)
        )
      }
      apiButton("socketURL") {
        try await chatClient.socketURL(roomID)
      }
    }
  }

  // MARK: - Commerce

  private var commerceSection: some View {
    Section("Commerce") {
      apiButton("createOrder") {
        try await commerceClient.createOrder(
          CreateOrderRequest(filter_id: filterID, total_price: 0)
        )
      }
      apiButton("fetchOrders") {
        try await commerceClient.fetchOrders()
      }
      apiButton("validatePayment") {
        try await commerceClient.validatePayment(
          PaymentValidationRequest(imp_uid: "test_imp_uid")
        )
      }
      apiButton("fetchPaymentReceipt") {
        try await commerceClient.fetchPaymentReceipt(orderCode)
      }
    }
  }

  // MARK: - Banner

  private var bannerSection: some View {
    Section("Banner") {
      apiButton("fetchMainBanners") {
        try await bannerClient.fetchMainBanners()
      }
    }
  }

  // MARK: - Notification

  private var notificationSection: some View {
    Section("Notification") {
      apiButton("sendTestPush") {
        try await notificationClient.sendTestPush(
          PushNotificationRequest(
            user_id: userID,
            title: "Test",
            subtitle: "Test Push",
            body: "This is a test notification"
          )
        )
      }
    }
  }

  // MARK: - Video

  private var videoSection: some View {
    Section("Video") {
      apiButton("list") {
        try await videoClient.list(
          VideoListQuery(next: nil, limit: 10)
        )
      }
      apiButton("fetchStream") {
        try await videoClient.fetchStream(videoID)
      }
      apiButton("setLike (true)") {
        try await videoClient.setLike(videoID, true)
      }
    }
  }

  // MARK: - Common

  private var commonSection: some View {
    Section("Common") {
      apiButton("fetchLogs") {
        try await commonClient.fetchLogs()
      }
    }
  }

  // MARK: - Helper

  private func apiButton(_ name: String, action: @escaping () async throws -> Any) -> some View {
    Button {
      Task {
        isLoading = true
        let start = CFAbsoluteTimeGetCurrent()
        do {
          let result = try await action()
          let elapsed = String(format: "%.2f", CFAbsoluteTimeGetCurrent() - start)
          let text = "[\(name)] (\(elapsed)s)\n\(result)"
          print("✅ \(text)")
          lastResult = "✅ \(text)"
        } catch {
          let elapsed = String(format: "%.2f", CFAbsoluteTimeGetCurrent() - start)
          let text = "[\(name)] (\(elapsed)s)\n\(error)"
          print("❌ \(text)")
          lastResult = "❌ \(text)"
        }
        isLoading = false
      }
    } label: {
      Text(name)
        .foregroundStyle(.blue)
    }
    .disabled(isLoading)
  }
}

#Preview {
  ContentView()
}
