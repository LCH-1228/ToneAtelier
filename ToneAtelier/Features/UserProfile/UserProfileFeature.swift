import ComposableArchitecture
import Foundation

@Reducer
struct UserProfileFeature {
  @ObservableState
  struct State: Equatable {
    let userID: String
    /// 프로필을 화면 그릴 수 있게 만들기 위한 최소 fallback. 검색 결과에서 받아 즉시 표시.
    var initialNick: String
    var initialIntroduction: String?
    var initialProfileImage: String?

    var summary: ProfileSummary?
    var featuredFilter: FeaturedFilter?
    var isLoading = false
    var isCreatingRoom = false
    var errorMessage: String?
    var baseURL: URL?

    @Presents var alert: AlertState<Action.Alert>?
  }

  struct LoadedProfile: Equatable, Sendable {
    var summary: ProfileSummary
    var featuredFilter: FeaturedFilter?
  }

  enum Action: Sendable {
    case task
    case sessionLoaded(baseURL: URL)
    case profileLoadResponse(Result<LoadedProfile, Error>)
    case messageButtonTapped
    case storeButtonTapped
    case featuredFilterTapped
    case createRoomResponse(Result<ChatRoom, Error>)
    case alert(PresentationAction<Alert>)
    case delegate(Delegate)

    enum Alert: Equatable, Sendable {
      case dismiss
    }

    enum Delegate: Equatable, Sendable {
      case messageRequested(ChatRoom, opponent: ChatUserSummary)
      case storeRequested(userID: String, headerName: String)
      case featuredFilterRequested(FeaturedFilter)
    }
  }

  @Dependency(\.userClient) private var userClient
  @Dependency(\.filterClient) private var filterClient
  @Dependency(\.postClient) private var postClient
  @Dependency(\.chatClient) private var chatClient
  @Dependency(\.sessionClient) private var sessionClient

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .task:
        guard !state.isLoading else { return .none }
        state.isLoading = true
        return loadProfile(into: &state)

      case let .sessionLoaded(baseURL):
        state.baseURL = baseURL
        return .none

      case let .profileLoadResponse(.success(loaded)):
        state.isLoading = false
        state.summary = loaded.summary
        state.featuredFilter = loaded.featuredFilter
        return .none

      case let .profileLoadResponse(.failure(error)):
        state.isLoading = false
        state.errorMessage = error.userProfileFacingMessage
        return .none

      case .messageButtonTapped:
        guard !state.isCreatingRoom else { return .none }
        state.isCreatingRoom = true
        let chatClient = chatClient
        let request = CreateChatRoomRequest(opponentID: state.userID)
        return .run { send in
          do {
            let room = try await chatClient.createRoom(request)
            await send(.createRoomResponse(.success(room)))
          } catch is CancellationError {
            return
          } catch {
            await send(.createRoomResponse(.failure(error)))
          }
        }

      case .storeButtonTapped:
        let userID = state.userID
        let headerName = state.summary?.nickname ?? state.initialNick
        return .send(.delegate(.storeRequested(userID: userID, headerName: headerName)))

      case .featuredFilterTapped:
        guard let filter = state.featuredFilter else { return .none }
        return .send(.delegate(.featuredFilterRequested(filter)))

      case let .createRoomResponse(.success(room)):
        state.isCreatingRoom = false
        let opponent = opponent(for: room, currentState: state)
        return .send(.delegate(.messageRequested(room, opponent: opponent)))

      case let .createRoomResponse(.failure(error)):
        state.isCreatingRoom = false
        state.alert = AlertState {
          TextState("채팅방을 만들지 못했어요")
        } actions: {
          ButtonState(role: .cancel, action: .dismiss) {
            TextState("확인")
          }
        } message: {
          TextState(error.userProfileFacingMessage)
        }
        return .none

      case .alert:
        return .none

      case .delegate:
        return .none
      }
    }
    .ifLet(\.$alert, action: \.alert)
  }

  private func opponent(for room: ChatRoom, currentState state: State) -> ChatUserSummary {
    if let participant = room.participants.first(where: { $0.userID == state.userID }) {
      return participant
    }
    return ChatUserSummary(
      userID: state.userID,
      nick: state.summary?.nickname ?? state.initialNick,
      name: state.summary?.name,
      introduction: state.summary?.bio ?? state.initialIntroduction,
      profileImage: state.summary?.avatarURL ?? state.initialProfileImage,
      hashTags: state.summary?.hashTags
    )
  }

  private func loadProfile(into state: inout State) -> Effect<Action> {
    let userID = state.userID
    let userClient = userClient
    let filterClient = filterClient
    let postClient = postClient
    let sessionClient = sessionClient

    return .run { send in
      let snapshot = await sessionClient.snapshot()
      await send(.sessionLoaded(baseURL: snapshot.configuration.baseURL))

      do {
        async let userTask = userClient.fetchOtherProfile(userID)
        async let filterTask = filterClient.userFilters(
          userID,
          UserFilterListQuery(next: nil, limit: 30, category: nil)
        )
        async let postTask = postClient.userPosts(
          userID,
          UserPostListQuery(category: nil, limit: 30, next: nil)
        )

        let userInfo = try await userTask
        let filtersResponse = try await filterTask
        let postsResponse = try await postTask

        let filterItems = ProfileResponseParser.userFilterListItems(from: filtersResponse.data)
        let featured = filterItems
          .sorted(by: { $0.likeCount > $1.likeCount })
          .first
          .map { ProfileResponseParser.featuredFilter(from: $0) }

        let summary = ProfileSummary(
          id: userInfo.userID,
          name: userInfo.name?.nilIfEmpty ?? userInfo.nick,
          nickname: userInfo.nick,
          bio: userInfo.introduction?.nilIfEmpty ?? "",
          avatarURL: userInfo.profileImage?.nilIfEmpty,
          email: "",
          phoneNum: nil,
          hashTags: userInfo.hashTags ?? [],
          stats: [
            ProfileStat(value: String(filterItems.count), label: "FILTER"),
            ProfileStat(value: String(postsResponse.data.count), label: "POSTS")
          ]
        )

        await send(.profileLoadResponse(.success(LoadedProfile(summary: summary, featuredFilter: featured))))
      } catch {
        await send(.profileLoadResponse(.failure(error)))
      }
    }
  }
}

private extension String {
  var nilIfEmpty: String? { isEmpty ? nil : self }
}

private extension Error {
  var userProfileFacingMessage: String {
    if let apiError = self as? APIError {
      switch apiError {
      case let .invalidBaseURL(message),
        let .invalidURL(message),
        let .transport(message),
        let .decoding(message):
        return message

      case .missingAccessToken, .missingRefreshToken:
        return "인증 정보가 없어 사용자 정보를 불러올 수 없어요."

      case let .invalidSession(statusCode):
        return "세션이 유효하지 않습니다. 다시 로그인해 주세요. (\(statusCode))"

      case let .server(statusCode, message, _):
        if let message, !message.isEmpty {
          return message
        }
        return "서버 응답을 불러오지 못했어요. (\(statusCode))"
      }
    }

    return "사용자 정보를 불러오지 못했어요. 잠시 후 다시 시도해 주세요."
  }
}
