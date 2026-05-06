//
//  MainTabFeature.swift
//  ToneAtelier
//
//  Created by Codex on 4/23/26.
//

import ComposableArchitecture
import Foundation

@Reducer
struct MainTabFeature {
  @ObservableState
  struct State: Equatable {
    @Presents var logoutConfirmation: AlertState<Action.Alert>?
    @Presents var messageFailureAlert: AlertState<Action.MessageFailureAlert>?
    var home = HomeFeature.State()
    var feed = FeedFeature.State(category: nil)
    var post = PostFeature.State()
    var chat = ChatTabFeature.State()
    var profile = ProfileFeature.State()
    var showsFeedBackButton = false
    var selectedTab: MainTab = .home
  }

  enum Action: BindableAction, Sendable {
    case alert(PresentationAction<Alert>)
    case binding(BindingAction<State>)
    case chat(ChatTabFeature.Action)
    case delegate(Delegate)
    case feed(FeedFeature.Action)
    case feedBackButtonTapped
    case home(HomeFeature.Action)
    case logoutButtonTapped
    case post(PostFeature.Action)
    case profile(ProfileFeature.Action)
    case task
    case pushTapped(roomID: String)
    case createRoomResponse(Result<ChatRoom, Error>, opponent: ChatUserSummary)
    case messageFailureAlert(PresentationAction<MessageFailureAlert>)

    enum Alert: Equatable, Sendable {
      case confirmLogout
    }

    enum MessageFailureAlert: Equatable, Sendable {}

    enum Delegate: Equatable, Sendable {
      case logoutRequested
    }
  }

  @Dependency(\.chatClient) private var chatClient
  @Dependency(\.chatPushClient) private var chatPushClient

  var body: some Reducer<State, Action> {
    Scope(state: \.home, action: \.home) {
      HomeFeature()
    }

    Scope(state: \.feed, action: \.feed) {
      FeedFeature()
    }

    Scope(state: \.post, action: \.post) {
      PostFeature()
    }

    Scope(state: \.chat, action: \.chat) {
      ChatTabFeature()
    }

    Scope(state: \.profile, action: \.profile) {
      ProfileFeature()
    }

    BindingReducer()

    Reduce { state, action in
      switch action {
      case .alert(.presented(.confirmLogout)):
        // 사용자가 confirmation alert에서 "로그아웃"을 선택한 경우에만 부모로 위임한다.
        // alert dismiss/cancel 경로는 별도 상태 변경 없이 기본 동작에 맡긴다.
        return .send(.delegate(.logoutRequested))

      case .alert:
        return .none

      case .binding(\.selectedTab):
        state.showsFeedBackButton = false
        return .none

      case .binding:
        return .none

      case .chat:
        return .none

      case let .feed(.delegate(.messageRequested(userID, nick, introduction, profileImage))):
        return startCreateRoom(userID: userID, nick: nick, introduction: introduction, profileImage: profileImage)

      case .feed:
        return .none

      case .feedBackButtonTapped:
        // cross-tab 으로 임시 적용된 카테고리 필터를 해제하고 Feed 를 초기 상태로 되돌린다.
        state.showsFeedBackButton = false
        state.selectedTab = .home
        state.feed = FeedFeature.State(category: nil)
        return .send(.feed(.task))

      case let .post(.delegate(.messageRequested(userID, nick, introduction, profileImage))):
        return startCreateRoom(userID: userID, nick: nick, introduction: introduction, profileImage: profileImage)

      case .post:
        return .none

      // ProfileFeature 가 path 안에서 자체 처리하므로 위임 불필요.
      case .profile(.delegate(.makeFilterRequested)):
        return .none

      case .profile(.delegate(.logoutRequested)):
        return .send(.logoutButtonTapped)

      case let .profile(.delegate(.messageRequested(userID, nick, introduction, profileImage))):
        return startCreateRoom(userID: userID, nick: nick, introduction: introduction, profileImage: profileImage)

      case .profile:
        return .none

      case let .home(.delegate(.feedCategorySelected(category))):
        // 새 State 로 교체 후 카테고리에 맞춰 재로드되도록 task 를 명시적으로 트리거한다.
        state.feed = FeedFeature.State(category: category)
        state.showsFeedBackButton = true
        state.selectedTab = .feed
        return .send(.feed(.task))

      case let .home(.delegate(.messageRequested(userID, nick, introduction, profileImage))):
        return startCreateRoom(userID: userID, nick: nick, introduction: introduction, profileImage: profileImage)

      case .home:
        return .none

      case .logoutButtonTapped:
        // 로그아웃은 채팅 내역과 사진 캐시를 모두 지우는 destructive 동작이므로
        // 곧바로 delegate를 발사하지 않고 confirmation alert로 한 번 더 확인을 받는다.
        state.logoutConfirmation = AlertState {
          TextState("로그아웃하시겠습니까?")
        } actions: {
          ButtonState(role: .cancel) {
            TextState("취소")
          }
          ButtonState(role: .destructive, action: .confirmLogout) {
            TextState("로그아웃")
          }
        } message: {
          TextState("이 기기에 저장된 채팅 내역과 사진이 모두 삭제됩니다.")
        }
        return .none

      case .delegate:
        return .none

      case .task:
        let chatPushClient = chatPushClient
        return .run { send in
          if let pendingRoomID = await chatPushClient.consumePending() {
            await send(.pushTapped(roomID: pendingRoomID))
          }
          for await roomID in chatPushClient.tappedRoomIDs() {
            await send(.pushTapped(roomID: roomID))
          }
        }
        .cancellable(id: "MainTabFeature.pushTappedSubscription", cancelInFlight: true)

      case let .pushTapped(roomID):
        state.selectedTab = .chat
        state.chat.deepLink(roomID: roomID)
        return .none

      case let .createRoomResponse(.success(room), opponent):
        routeToChatRoom(state: &state, room: room, opponent: opponent)
        return .none

      case let .createRoomResponse(.failure(error), _):
        state.messageFailureAlert = AlertState {
          TextState("채팅방을 만들지 못했어요")
        } actions: {
          ButtonState(role: .cancel) {
            TextState("확인")
          }
        } message: {
          TextState(error.messageFailureFacingMessage)
        }
        return .none

      case .messageFailureAlert:
        return .none
      }
    }
    .ifLet(\.$logoutConfirmation, action: \.alert)
    .ifLet(\.$messageFailureAlert, action: \.messageFailureAlert)
  }

  private func routeToChatRoom(state: inout State, room: ChatRoom, opponent: ChatUserSummary) {
    state.selectedTab = .chat
    state.chat.path.removeAll()
    state.chat.path.append(
      .chatRoom(ChatRoomFeature.State(roomID: room.roomID, opponent: opponent))
    )
  }

  private func startCreateRoom(
    userID: String,
    nick: String,
    introduction: String?,
    profileImage: String?
  ) -> Effect<Action> {
    let opponent = ChatUserSummary(
      userID: userID,
      nick: nick,
      name: nil,
      introduction: introduction,
      profileImage: profileImage,
      hashTags: nil
    )
    let chatClient = chatClient
    return .run { send in
      do {
        let room = try await chatClient.createRoom(.init(opponentID: userID))
        await send(.createRoomResponse(.success(room), opponent: opponent))
      } catch is CancellationError {
        return
      } catch {
        await send(.createRoomResponse(.failure(error), opponent: opponent))
      }
    }
  }
}

private extension Error {
  var messageFailureFacingMessage: String {
    if let apiError = self as? APIError {
      switch apiError {
      case let .invalidBaseURL(message),
           let .invalidURL(message),
           let .transport(message),
           let .decoding(message):
        return message
      case .missingAccessToken, .missingRefreshToken:
        return "인증 정보가 없어 채팅방을 만들 수 없어요."
      case let .invalidSession(statusCode):
        return "세션이 유효하지 않습니다. 다시 로그인해 주세요. (\(statusCode))"
      case let .server(statusCode, message, _):
        if let message, !message.isEmpty {
          return message
        }
        return "서버 응답을 불러오지 못했어요. (\(statusCode))"
      }
    }
    return "잠시 후 다시 시도해 주세요."
  }
}
