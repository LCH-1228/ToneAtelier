//
//  APIRouterTestViews.swift
//  ToneAtelier
//
//  Created by Codex on 4/23/26.
//

import ComposableArchitecture
import SwiftUI

struct AuthRouterTestView: View {
  @Dependency(\.authClient) private var authClient

  var body: some View {
    APITestScreen(title: "Auth") { runner in
      Section("Actions") {
        APITestActionButton(title: "refresh", runner: runner) {
          try await authClient.refresh()
        }
      }
    }
  }
}

struct UserRouterTestView: View {
  @Dependency(\.userClient) private var userClient

  @State private var email = "filters@photo.com"
  @State private var password = "filter1234@"
  @State private var nick = "사진작까"
  @State private var name = "사진작까"
  @State private var introduction = ""
  @State private var phoneNum = ""
  @State private var hashTags = ""
  @State private var deviceToken = ""
  @State private var userID = ""
  @State private var oauthToken = "test_token"
  @State private var appleIDToken = "test_token"
  @State private var searchNick = "사진작까"
  @State private var profileImagePath = ""

  var body: some View {
    APITestScreen(title: "User") { runner in
      Section("Account Inputs") {
        TextField("email", text: $email)
          .keyboardType(.emailAddress)
        TextField("password", text: $password)
        TextField("nick", text: $nick)
        TextField("name", text: $name)
        TextField("deviceToken", text: $deviceToken)
        TextField("oauthToken", text: $oauthToken)
        TextField("appleIDToken", text: $appleIDToken)
      }

      Section("Profile Inputs") {
        TextField("userID", text: $userID)
        TextField("searchNick", text: $searchNick)
        TextField("introduction", text: $introduction, axis: .vertical)
          .lineLimit(2...4)
        TextField("phoneNum", text: $phoneNum)
        TextField("hashTags (CSV)", text: $hashTags)
        TextField("profileImage path", text: $profileImagePath)
      }

      Section("Actions") {
        APITestActionButton(title: "validateEmail", runner: runner) {
          try await userClient.validateEmail(
            EmailValidationRequest(email: try requiredString(email, field: "email"))
          )
        }

        APITestActionButton(title: "join", runner: runner) {
          try await userClient.join(
            JoinRequest(
              email: try requiredString(email, field: "email"),
              password: try requiredString(password, field: "password"),
              nick: try requiredString(nick, field: "nick"),
              name: try requiredString(name, field: "name"),
              introduction: optionalString(introduction),
              phoneNum: optionalString(phoneNum),
              hashTags: csvValues(hashTags),
              deviceToken: optionalString(deviceToken)
            )
          )
        }

        APITestActionButton(title: "login", runner: runner) {
          try await userClient.login(
            EmailLoginRequest(
              email: try requiredString(email, field: "email"),
              password: try requiredString(password, field: "password"),
              deviceToken: optionalString(deviceToken)
            )
          )
        }

        APITestActionButton(title: "loginKakao", runner: runner) {
          try await userClient.loginKakao(
            KakaoLoginRequest(
              oauthToken: try requiredString(oauthToken, field: "oauthToken"),
              deviceToken: optionalString(deviceToken)
            )
          )
        }

        APITestActionButton(title: "loginApple", runner: runner) {
          try await userClient.loginApple(
            AppleLoginRequest(
              idToken: try requiredString(appleIDToken, field: "appleIDToken"),
              deviceToken: optionalString(deviceToken)
            )
          )
        }

        APITestActionButton(title: "logout", runner: runner) {
          try await userClient.logout()
        }

        APITestActionButton(title: "updateDeviceToken", runner: runner) {
          try await userClient.updateDeviceToken(
            DeviceTokenRequest(deviceToken: try requiredString(deviceToken, field: "deviceToken"))
          )
        }

        APITestActionButton(title: "fetchOtherProfile", runner: runner) {
          try await userClient.fetchOtherProfile(try requiredString(userID, field: "userID"))
        }

        APITestActionButton(title: "uploadProfileImage (sample PNG)", runner: runner) {
          let response = try await userClient.uploadProfileImage(
            sampleImageUploadFile(named: "profile-test.png")
          )
          await MainActor.run {
            profileImagePath = response.profileImage
          }
          return response
        }

        APITestActionButton(title: "fetchMyProfile", runner: runner) {
          try await userClient.fetchMyProfile()
        }

        APITestActionButton(title: "updateMyProfile", runner: runner) {
          try await userClient.updateMyProfile(
            UpdateMyProfileRequest(
              nick: optionalString(nick),
              name: optionalString(name),
              introduction: optionalString(introduction),
              phoneNum: optionalString(phoneNum),
              profileImage: optionalString(profileImagePath),
              hashTags: csvValues(hashTags)
            )
          )
        }

        APITestActionButton(title: "fetchTodayAuthor", runner: runner) {
          try await userClient.fetchTodayAuthor()
        }

        APITestActionButton(title: "searchUsers", runner: runner) {
          try await userClient.searchUsers(optionalString(searchNick))
        }
      }
    }
  }
}

struct PostRouterTestView: View {
  @Dependency(\.postClient) private var postClient

  @State private var postID = ""
  @State private var userID = ""
  @State private var commentID = ""
  @State private var category = "test"
  @State private var title = "Test Post"
  @State private var content = "Test Content"
  @State private var latitude = "37.5665"
  @State private var longitude = "126.9780"
  @State private var maxDistance = ""
  @State private var limit = "10"
  @State private var next = ""
  @State private var orderBy = ""
  @State private var searchTitle = "test"
  @State private var files = ""
  @State private var likeStatus = true
  @State private var commentContent = "Test comment"
  @State private var editedCommentContent = "Edited comment"

  var body: some View {
    APITestScreen(title: "Post") { runner in
      Section("Identifiers") {
        TextField("postID", text: $postID)
        TextField("userID", text: $userID)
        TextField("commentID", text: $commentID)
      }

      Section("Request Inputs") {
        TextField("category", text: $category)
        TextField("title", text: $title)
        TextField("content", text: $content, axis: .vertical)
          .lineLimit(2...4)
        TextField("latitude", text: $latitude)
          .keyboardType(.numbersAndPunctuation)
        TextField("longitude", text: $longitude)
          .keyboardType(.numbersAndPunctuation)
        TextField("maxDistance", text: $maxDistance)
          .keyboardType(.numberPad)
        TextField("limit", text: $limit)
          .keyboardType(.numberPad)
        TextField("next", text: $next)
        TextField("order_by", text: $orderBy)
        TextField("search title", text: $searchTitle)
        TextField("uploaded file paths (CSV)", text: $files, axis: .vertical)
          .lineLimit(2...4)
        TextField("comment content", text: $commentContent, axis: .vertical)
          .lineLimit(2...4)
        TextField("edited comment content", text: $editedCommentContent, axis: .vertical)
          .lineLimit(2...4)
        Toggle("like_status", isOn: $likeStatus)
      }

      Section("Actions") {
        APITestActionButton(title: "uploadFiles (sample PNG)", runner: runner) {
          let response = try await postClient.uploadFiles(
            sampleImageUploadFiles(prefix: "post-upload")
          )
          await MainActor.run {
            files = response.files.joined(separator: ", ")
          }
          return response
        }

        APITestActionButton(title: "create", runner: runner) {
          try await postClient.create(
            CreatePostRequest(
              category: try requiredString(category, field: "category"),
              title: try requiredString(title, field: "title"),
              content: try requiredString(content, field: "content"),
              latitude: try requiredDouble(latitude, field: "latitude"),
              longitude: try requiredDouble(longitude, field: "longitude"),
              files: csvValues(files)
            )
          )
        }

        APITestActionButton(title: "listGeolocation", runner: runner) {
          try await postClient.listGeolocation(
            GeolocationPostsQuery(
              category: optionalString(category),
              longitude: try optionalDouble(longitude, field: "longitude"),
              latitude: try optionalDouble(latitude, field: "latitude"),
              maxDistance: try optionalInt(maxDistance, field: "maxDistance"),
              limit: try optionalInt(limit, field: "limit"),
              next: optionalString(next),
              order_by: optionalString(orderBy)
            )
          )
        }

        APITestActionButton(title: "search", runner: runner) {
          try await postClient.search(optionalString(searchTitle))
        }

        APITestActionButton(title: "detail", runner: runner) {
          try await postClient.detail(try requiredString(postID, field: "postID"))
        }

        APITestActionButton(title: "update", runner: runner) {
          try await postClient.update(
            try requiredString(postID, field: "postID"),
            UpdatePostRequest(
              category: optionalString(category),
              title: optionalString(title),
              content: optionalString(content),
              latitude: try optionalDouble(latitude, field: "latitude"),
              longitude: try optionalDouble(longitude, field: "longitude"),
              files: csvValues(files)
            )
          )
        }

        APITestActionButton(title: "delete", runner: runner) {
          try await postClient.delete(try requiredString(postID, field: "postID"))
        }

        APITestActionButton(title: "setLike", runner: runner) {
          try await postClient.setLike(
            try requiredString(postID, field: "postID"),
            likeStatus
          )
        }

        APITestActionButton(title: "userPosts", runner: runner) {
          try await postClient.userPosts(
            try requiredString(userID, field: "userID"),
            UserPostListQuery(
              category: optionalString(category),
              limit: try optionalInt(limit, field: "limit"),
              next: optionalString(next)
            )
          )
        }

        APITestActionButton(title: "likedPosts", runner: runner) {
          try await postClient.likedPosts(
            UserPostListQuery(
              category: optionalString(category),
              limit: try optionalInt(limit, field: "limit"),
              next: optionalString(next)
            )
          )
        }

        APITestActionButton(title: "createComment", runner: runner) {
          try await postClient.createComment(
            try requiredString(postID, field: "postID"),
            CommentWriteRequest(
              parent_comment_id: nil,
              content: try requiredString(commentContent, field: "comment content")
            )
          )
        }

        APITestActionButton(title: "updateComment", runner: runner) {
          try await postClient.updateComment(
            try requiredString(postID, field: "postID"),
            try requiredString(commentID, field: "commentID"),
            CommentEditRequest(content: try requiredString(editedCommentContent, field: "edited comment content"))
          )
        }

        APITestActionButton(title: "deleteComment", runner: runner) {
          try await postClient.deleteComment(
            try requiredString(postID, field: "postID"),
            try requiredString(commentID, field: "commentID")
          )
        }
      }
    }
  }
}

struct FilterRouterTestView: View {
  @Dependency(\.filterClient) private var filterClient

  @State private var filterID = ""
  @State private var userID = ""
  @State private var commentID = ""
  @State private var category = "test"
  @State private var title = "Test Filter"
  @State private var description = "Test filter description"
  @State private var price = "0"
  @State private var limit = "10"
  @State private var next = ""
  @State private var orderBy = ""
  @State private var files = ""
  @State private var photoMetadata = ""
  @State private var filterValues = "{}"
  @State private var likeStatus = true
  @State private var commentContent = "Test comment"
  @State private var editedCommentContent = "Edited comment"

  var body: some View {
    APITestScreen(title: "Filter") { runner in
      Section("Identifiers") {
        TextField("filterID", text: $filterID)
        TextField("userID", text: $userID)
        TextField("commentID", text: $commentID)
      }

      Section("Request Inputs") {
        TextField("category", text: $category)
        TextField("title", text: $title)
        TextField("description", text: $description, axis: .vertical)
          .lineLimit(2...4)
        TextField("price", text: $price)
          .keyboardType(.numberPad)
        TextField("limit", text: $limit)
          .keyboardType(.numberPad)
        TextField("next", text: $next)
        TextField("order_by", text: $orderBy)
        TextField("uploaded file paths (CSV)", text: $files, axis: .vertical)
          .lineLimit(2...4)
        TextField("photo_metadata JSON", text: $photoMetadata, axis: .vertical)
          .lineLimit(2...4)
        TextField("filter_values JSON", text: $filterValues, axis: .vertical)
          .lineLimit(2...4)
        TextField("comment content", text: $commentContent, axis: .vertical)
          .lineLimit(2...4)
        TextField("edited comment content", text: $editedCommentContent, axis: .vertical)
          .lineLimit(2...4)
        Toggle("like_status", isOn: $likeStatus)
      }

      Section("Actions") {
        APITestActionButton(title: "uploadFiles (sample PNG)", runner: runner) {
          let response = try await filterClient.uploadFiles(
            sampleImageUploadFiles(prefix: "filter-upload")
          )
          await MainActor.run {
            files = response.files.joined(separator: ", ")
          }
          return response
        }

        APITestActionButton(title: "create", runner: runner) {
          try await filterClient.create(
            CreateFilterRequest(
              category: try requiredString(category, field: "category"),
              title: try requiredString(title, field: "title"),
              price: try optionalInt(price, field: "price"),
              description: try requiredString(description, field: "description"),
              files: csvValues(files) ?? [],
              photo_metadata: try optionalJSONValue(photoMetadata, field: "photo_metadata"),
              filter_values: try requiredJSONValue(filterValues, field: "filter_values")
            )
          )
        }

        APITestActionButton(title: "list", runner: runner) {
          try await filterClient.list(
            FilterListQuery(
              next: optionalString(next),
              limit: try optionalInt(limit, field: "limit"),
              category: optionalString(category),
              order_by: optionalString(orderBy)
            )
          )
        }

        APITestActionButton(title: "detail", runner: runner) {
          try await filterClient.detail(try requiredString(filterID, field: "filterID"))
        }

        APITestActionButton(title: "update", runner: runner) {
          try await filterClient.update(
            try requiredString(filterID, field: "filterID"),
            UpdateFilterRequest(
              category: optionalString(category),
              title: optionalString(title),
              price: try optionalInt(price, field: "price"),
              description: optionalString(description),
              files: csvValues(files),
              photo_metadata: try optionalJSONValue(photoMetadata, field: "photo_metadata"),
              filter_values: try optionalJSONValue(filterValues, field: "filter_values")
            )
          )
        }

        APITestActionButton(title: "delete", runner: runner) {
          try await filterClient.delete(try requiredString(filterID, field: "filterID"))
        }

        APITestActionButton(title: "setLike", runner: runner) {
          try await filterClient.setLike(
            try requiredString(filterID, field: "filterID"),
            likeStatus
          )
        }

        APITestActionButton(title: "userFilters", runner: runner) {
          try await filterClient.userFilters(
            try requiredString(userID, field: "userID"),
            UserFilterListQuery(
              next: optionalString(next),
              limit: try optionalInt(limit, field: "limit"),
              category: optionalString(category)
            )
          )
        }

        APITestActionButton(title: "likedFilters", runner: runner) {
          try await filterClient.likedFilters(
            UserFilterListQuery(
              next: optionalString(next),
              limit: try optionalInt(limit, field: "limit"),
              category: optionalString(category)
            )
          )
        }

        APITestActionButton(title: "hotTrend", runner: runner) {
          try await filterClient.hotTrend()
        }

        APITestActionButton(title: "todayFilter", runner: runner) {
          try await filterClient.todayFilter()
        }

        APITestActionButton(title: "createComment", runner: runner) {
          try await filterClient.createComment(
            try requiredString(filterID, field: "filterID"),
            CommentWriteRequest(
              parent_comment_id: nil,
              content: try requiredString(commentContent, field: "comment content")
            )
          )
        }

        APITestActionButton(title: "updateComment", runner: runner) {
          try await filterClient.updateComment(
            try requiredString(filterID, field: "filterID"),
            try requiredString(commentID, field: "commentID"),
            CommentEditRequest(content: try requiredString(editedCommentContent, field: "edited comment content"))
          )
        }

        APITestActionButton(title: "deleteComment", runner: runner) {
          try await filterClient.deleteComment(
            try requiredString(filterID, field: "filterID"),
            try requiredString(commentID, field: "commentID")
          )
        }
      }
    }
  }
}

struct ChatRouterTestView: View {
  @Dependency(\.chatClient) private var chatClient

  @State private var opponentID = ""
  @State private var roomID = ""
  @State private var messageContent = "Test message"
  @State private var messageFiles = ""
  @State private var historyNext = ""

  var body: some View {
    APITestScreen(title: "Chat") { runner in
      Section("Inputs") {
        TextField("opponent userID", text: $opponentID)
        TextField("roomID", text: $roomID)
        TextField("message content", text: $messageContent, axis: .vertical)
          .lineLimit(2...4)
        TextField("message file paths (CSV)", text: $messageFiles, axis: .vertical)
          .lineLimit(2...4)
        TextField("history next", text: $historyNext)
      }

      Section("Actions") {
        APITestActionButton(title: "createRoom", runner: runner) {
          try await chatClient.createRoom(
            CreateChatRoomRequest(opponent_id: try requiredString(opponentID, field: "opponent userID"))
          )
        }

        APITestActionButton(title: "listRooms", runner: runner) {
          try await chatClient.listRooms()
        }

        APITestActionButton(title: "uploadFiles (sample PNG)", runner: runner) {
          let response = try await chatClient.uploadFiles(
            try requiredString(roomID, field: "roomID"),
            sampleImageUploadFiles(prefix: "chat-upload")
          )
          await MainActor.run {
            messageFiles = response.files.joined(separator: ", ")
          }
          return response
        }

        APITestActionButton(title: "sendMessage", runner: runner) {
          try await chatClient.sendMessage(
            try requiredString(roomID, field: "roomID"),
            SendChatRequest(
              content: optionalString(messageContent),
              files: csvValues(messageFiles)
            )
          )
        }

        APITestActionButton(title: "listMessages", runner: runner) {
          try await chatClient.listMessages(
            try requiredString(roomID, field: "roomID"),
            ChatHistoryQuery(next: optionalString(historyNext))
          )
        }

        APITestActionButton(title: "socketURL", runner: runner) {
          try await chatClient.socketURL(try requiredString(roomID, field: "roomID"))
        }
      }
    }
  }
}

struct CommerceRouterTestView: View {
  @Dependency(\.commerceClient) private var commerceClient

  @State private var filterID = ""
  @State private var totalPrice = "0"
  @State private var impUID = "test_imp_uid"
  @State private var orderCode = ""

  var body: some View {
    APITestScreen(title: "Commerce") { runner in
      Section("Inputs") {
        TextField("filterID", text: $filterID)
        TextField("totalPrice", text: $totalPrice)
          .keyboardType(.numberPad)
        TextField("impUID", text: $impUID)
        TextField("orderCode", text: $orderCode)
      }

      Section("Actions") {
        APITestActionButton(title: "createOrder", runner: runner) {
          let response = try await commerceClient.createOrder(
            CreateOrderRequest(
              filter_id: try requiredString(filterID, field: "filterID"),
              total_price: try requiredInt(totalPrice, field: "totalPrice")
            )
          )
          await MainActor.run {
            orderCode = response.order_code
          }
          return response
        }

        APITestActionButton(title: "fetchOrders", runner: runner) {
          try await commerceClient.fetchOrders()
        }

        APITestActionButton(title: "validatePayment", runner: runner) {
          try await commerceClient.validatePayment(
            PaymentValidationRequest(imp_uid: try requiredString(impUID, field: "impUID"))
          )
        }

        APITestActionButton(title: "fetchPaymentReceipt", runner: runner) {
          try await commerceClient.fetchPaymentReceipt(
            try requiredString(orderCode, field: "orderCode")
          )
        }
      }
    }
  }
}

struct BannerRouterTestView: View {
  @Dependency(\.bannerClient) private var bannerClient

  var body: some View {
    APITestScreen(title: "Banner") { runner in
      Section("Actions") {
        APITestActionButton(title: "fetchMainBanners", runner: runner) {
          try await bannerClient.fetchMainBanners()
        }
      }
    }
  }
}

struct NotificationRouterTestView: View {
  @Dependency(\.notificationClient) private var notificationClient

  @State private var userID = ""
  @State private var title = "Test"
  @State private var subtitle = "Test Push"
  @State private var bodyText = "This is a test notification"

  var body: some View {
    APITestScreen(title: "Notification") { runner in
      Section("Inputs") {
        TextField("userID", text: $userID)
        TextField("title", text: $title)
        TextField("subtitle", text: $subtitle)
        TextField("body", text: $bodyText, axis: .vertical)
          .lineLimit(2...4)
      }

      Section("Actions") {
        APITestActionButton(title: "sendTestPush", runner: runner) {
          try await notificationClient.sendTestPush(
            PushNotificationRequest(
              user_id: try requiredString(userID, field: "userID"),
              title: try requiredString(title, field: "title"),
              subtitle: subtitle,
              body: try requiredString(bodyText, field: "body")
            )
          )
        }
      }
    }
  }
}

struct VideoRouterTestView: View {
  @Dependency(\.videoClient) private var videoClient

  @State private var videoID = ""
  @State private var next = ""
  @State private var limit = "10"
  @State private var likeStatus = true

  var body: some View {
    APITestScreen(title: "Video") { runner in
      Section("Inputs") {
        TextField("videoID", text: $videoID)
        TextField("next", text: $next)
        TextField("limit", text: $limit)
          .keyboardType(.numberPad)
        Toggle("like_status", isOn: $likeStatus)
      }

      Section("Actions") {
        APITestActionButton(title: "list", runner: runner) {
          try await videoClient.list(
            VideoListQuery(
              next: optionalString(next),
              limit: try optionalInt(limit, field: "limit")
            )
          )
        }

        APITestActionButton(title: "fetchStream", runner: runner) {
          try await videoClient.fetchStream(try requiredString(videoID, field: "videoID"))
        }

        APITestActionButton(title: "setLike", runner: runner) {
          try await videoClient.setLike(
            try requiredString(videoID, field: "videoID"),
            likeStatus
          )
        }
      }
    }
  }
}

struct CommonRouterTestView: View {
  @Dependency(\.commonClient) private var commonClient

  var body: some View {
    APITestScreen(title: "Common") { runner in
      Section("Actions") {
        APITestActionButton(title: "fetchLogs", runner: runner) {
          try await commonClient.fetchLogs()
        }
      }
    }
  }
}
