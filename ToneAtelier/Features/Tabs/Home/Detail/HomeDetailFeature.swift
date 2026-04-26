//
//  HomeDetailFeature.swift
//  ToneAtelier
//
//  Created by Codex on 4/25/26.
//

import ComposableArchitecture
import Foundation

@Reducer
struct HomeDetailFeature {
  @Dependency(\.homeDetailClient) private var homeDetailClient

  @ObservableState
  struct State: Equatable {
    let id: String
    var title: String
    var summary: String?
    var likeCount: Int?
    var price: Int
    var buyerCount: Int
    var isLiked: Bool
    var isPurchased: Bool
    var afterImageURL: String?
    var beforeImageURL: String?
    var authorName: String
    var authorSubtitle: String
    var authorProfileImageURL: String?
    var authorTags: [String]
    var exif: HomeDetailExifInfo
    var presets: [HomeDetailPreset]
    var isLoadingDetail = false
    var hasLoadedDetail = false
    var errorMessage: String?

    init(
      id: String,
      title: String,
      summary: String?,
      likeCount: Int?,
      imageURL: String? = nil,
      isPurchased: Bool = true
    ) {
      self.id = id
      self.title = title
      self.summary = summary
      self.likeCount = likeCount
      self.price = 2_000
      self.buyerCount = 2_400
      self.isLiked = false
      self.isPurchased = isPurchased
      self.afterImageURL = imageURL
      self.beforeImageURL = imageURL
      self.authorName = "윤새싹"
      self.authorSubtitle = "SESAC YOON"
      self.authorProfileImageURL = nil
      self.authorTags = ["#섬세함", "#자연", "#미니멀"]
      self.exif = .placeholder
      self.presets = HomeDetailDesignData.defaultPresets
    }

    init(trend: HomeTrend) {
      self.init(
        id: trend.id,
        title: trend.title,
        summary: nil,
        likeCount: trend.likeCount,
        imageURL: trend.imageURL
      )
    }

    init(featuredFilter: HomeFeaturedFilter) {
      self.init(
        id: featuredFilter.id,
        title: featuredFilter.title,
        summary: featuredFilter.summary,
        likeCount: nil,
        imageURL: featuredFilter.imageURL
      )
    }

    var navigationTitle: String {
      "Detail"
    }
  }

  enum Action: Sendable {
    case detailResponse(Result<HomeDetailLoadedData, Error>)
    case likeButtonTapped
    case noop
    case task
  }

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case let .detailResponse(.success(data)):
        state.isLoadingDetail = false
        state.hasLoadedDetail = true
        state.errorMessage = nil
        state.apply(data)
        return .none

      case let .detailResponse(.failure(error)):
        state.isLoadingDetail = false
        state.hasLoadedDetail = true
        state.errorMessage = error.userFacingMessage
        return .none

      case .likeButtonTapped:
        state.isLiked.toggle()
        state.likeCount = max(0, (state.likeCount ?? 0) + (state.isLiked ? 1 : -1))
        return .none

      case .noop:
        return .none

      case .task:
        guard !state.isLoadingDetail, !state.hasLoadedDetail else {
          return .none
        }

        state.isLoadingDetail = true
        state.errorMessage = nil

        let filterID = state.id
        let homeDetailClient = homeDetailClient

        return .run { send in
          await send(
            .detailResponse(
              Result {
                try await homeDetailClient.fetchDetail(filterID)
              }
            )
          )
        }
        .cancellable(id: "HomeDetailFeature.detail", cancelInFlight: true)
      }
    }
  }
}

private extension HomeDetailFeature.State {
  mutating func apply(_ data: HomeDetailLoadedData) {
    title = data.title
    summary = data.description
    price = data.price
    buyerCount = data.buyerCount
    likeCount = data.likeCount
    isLiked = data.isLiked
    isPurchased = data.isPurchased
    let resolvedAfterImageURL = data.afterImageURL ?? afterImageURL
    afterImageURL = resolvedAfterImageURL
    beforeImageURL = data.beforeImageURL ?? resolvedAfterImageURL ?? beforeImageURL
    authorName = data.authorName
    authorSubtitle = data.authorSubtitle
    authorProfileImageURL = data.authorProfileImageURL
    authorTags = data.authorTags
    exif = data.exif
    presets = data.presets
  }
}

private extension Error {
  var userFacingMessage: String {
    if let apiError = self as? APIError {
      switch apiError {
      case let .invalidBaseURL(message),
        let .invalidURL(message),
        let .transport(message),
        let .decoding(message):
        return message

      case .missingAccessToken, .missingRefreshToken:
        return "인증 정보가 없어 필터 상세를 불러올 수 없어요."

      case let .invalidSession(statusCode):
        return "세션이 유효하지 않습니다. 다시 로그인해 주세요. (\(statusCode))"

      case let .server(statusCode, message, _):
        if let message, !message.isEmpty {
          return message
        }
        return "필터 상세 응답을 불러오지 못했어요. (\(statusCode))"
      }
    }

    return "필터 상세를 불러오지 못했어요. 잠시 후 다시 시도해 주세요."
  }
}
