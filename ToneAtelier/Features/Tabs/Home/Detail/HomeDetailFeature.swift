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
  @Dependency(\.commerceClient) private var commerceClient

  @ObservableState
  struct State: Equatable {
    let id: String
    var title: String
    var summary: String?
    var likeCount: Int?
    var price: Int
    var buyerCount: Int
    var isLiked: Bool
    var isLikeRequestInFlight = false
    var isPurchased: Bool
    var afterImageURL: String?
    var beforeImageURL: String?
    var comparisonSplitRatio = 0.68
    var authorName: String
    var authorSubtitle: String
    var authorProfileImageURL: String?
    var authorTags: [String]
    var exif: HomeDetailExifInfo
    var presets: [HomeDetailPreset]
    var isLoadingDetail = false
    var hasLoadedDetail = false
    var errorMessage: String?
    var pendingLikeSnapshot: HomeDetailLikeSnapshot?
    /// 결제 시트 트리거. nil이 아니면 fullScreenCover로 IamportPaymentSheet가 표시된다.
    var activePayment: IamportPaymentRequest?
    /// 주문 생성 ~ 결제 검증 완료까지 동안 true.
    var isPurchaseInFlight = false
    /// 현재 진행 중인 결제 흐름의 merchantUID. nil이면 결제 흐름이 비활성 상태로 간주하고
    /// 시트 dismiss 이후 도착하는 SDK 콜백/주문 응답을 무시한다.
    var pendingPaymentMerchantUID: String?
    /// 결제 실패 등 사용자에게 즉시 노출할 알림.
    @Presents var alert: AlertState<Action.Alert>?

    init(
      id: String,
      title: String,
      summary: String?,
      likeCount: Int?,
      imageURL: String? = nil,
      isPurchased: Bool = false
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
    case alert(PresentationAction<Alert>)
    case detailResponse(Result<HomeDetailLoadedData, Error>)
    case delegate(Delegate)
    case comparisonSplitRatioChanged(Double)
    case likeButtonTapped
    case likeResponse(Result<Bool, Error>)
    case noop
    case purchaseButtonTapped
    case orderCreated(Result<OrderCreatedResponse, Error>)
    case paymentSheetDismissed
    case paymentCompleted(IamportPaymentResult)
    case paymentValidated(Result<JSONValue, Error>)
    case task

    enum Alert: Equatable, Sendable {}

    enum Delegate: Equatable, Sendable {
      case likeStatusChanged(id: String, isLiked: Bool, likeCount: Int?)
    }
  }

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .alert:
        return .none

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

      case let .comparisonSplitRatioChanged(ratio):
        state.comparisonSplitRatio = min(0.92, max(0.08, ratio))
        return .none

      case .delegate:
        return .none

      case .likeButtonTapped:
        guard !state.isLikeRequestInFlight else {
          return .none
        }

        state.pendingLikeSnapshot = HomeDetailLikeSnapshot(
          isLiked: state.isLiked,
          likeCount: state.likeCount
        )
        let targetStatus = !state.isLiked
        state.isLikeRequestInFlight = true
        state.applyLikeStatus(targetStatus)

        let id = state.id
        let likeCount = state.likeCount
        let homeDetailClient = homeDetailClient

        return .concatenate(
          .send(.delegate(.likeStatusChanged(id: id, isLiked: targetStatus, likeCount: likeCount))),
          .run { send in
            await send(
              .likeResponse(
                Result {
                  try await homeDetailClient.setLike(id, targetStatus)
                }
              )
            )
          }
        )

      case let .likeResponse(.success(confirmedStatus)):
        state.isLikeRequestInFlight = false
        state.pendingLikeSnapshot = nil
        state.applyLikeStatus(confirmedStatus)
        return .send(
          .delegate(
            .likeStatusChanged(
              id: state.id,
              isLiked: state.isLiked,
              likeCount: state.likeCount
            )
          )
        )

      case .likeResponse(.failure):
        state.isLikeRequestInFlight = false
        if let snapshot = state.pendingLikeSnapshot {
          state.isLiked = snapshot.isLiked
          state.likeCount = snapshot.likeCount
        }
        state.pendingLikeSnapshot = nil
        return .send(
          .delegate(
            .likeStatusChanged(
              id: state.id,
              isLiked: state.isLiked,
              likeCount: state.likeCount
            )
          )
        )

      case .noop:
        return .none

      // MARK: - 결제 흐름
      case .purchaseButtonTapped:
        // 이미 구매했거나 진행 중이면 무시. 중복 주문 생성을 막는다.
        guard !state.isPurchased, !state.isPurchaseInFlight else {
          return .none
        }

        state.isPurchaseInFlight = true

        let request = CreateOrderRequest(filter_id: state.id, total_price: state.price)
        let commerceClient = commerceClient

        return .run { send in
          await send(
            .orderCreated(
              Result {
                try await commerceClient.createOrder(request)
              }
            )
          )
        }
        .cancellable(id: "HomeDetailFeature.createOrder", cancelInFlight: true)

      case let .orderCreated(.success(response)):
        // 사용자가 이미 흐름을 취소(시트 dismiss)한 뒤 도착한 늦은 응답은 무시한다.
        guard state.isPurchaseInFlight else {
          return .none
        }
        // 주문 생성 성공 → 결제 시트 트리거. 콜백 가드용으로 merchantUID도 보관.
        state.pendingPaymentMerchantUID = response.order_code
        state.activePayment = IamportPaymentRequest(
          merchantUID: response.order_code,
          amount: state.price,
          name: state.title,
          appScheme: AppURLScheme.payment
        )
        return .none

      case let .orderCreated(.failure(error)):
        // 사용자가 이미 흐름을 취소했다면 알림을 띄우지 않는다.
        guard state.isPurchaseInFlight else {
          return .none
        }
        state.isPurchaseInFlight = false
        state.pendingPaymentMerchantUID = nil
        state.alert = Self.makePurchaseFailureAlert(message: error.userFacingMessage)
        return .none

      case .paymentSheetDismissed:
        // 사용자가 시스템 dismiss 등으로 시트를 내린 경우의 정리 경로.
        // pendingPaymentMerchantUID를 비워 늦게 도착하는 SDK 콜백/주문 응답을 가드한다.
        state.activePayment = nil
        state.isPurchaseInFlight = false
        state.pendingPaymentMerchantUID = nil
        return .merge(
          .cancel(id: "HomeDetailFeature.createOrder"),
          .cancel(id: "HomeDetailFeature.validatePayment")
        )

      case let .paymentCompleted(result):
        // 시트가 이미 dismiss된 후 도착한 콜백은 무시한다.
        guard state.pendingPaymentMerchantUID != nil else {
          return .none
        }

        // SDK가 결과를 돌려줬으니 시트는 닫는다.
        state.activePayment = nil
        state.pendingPaymentMerchantUID = nil

        guard result.success, let impUID = result.impUID else {
          state.isPurchaseInFlight = false
          let message = result.errorMessage ?? "결제가 취소되었습니다."
          state.alert = Self.makePurchaseFailureAlert(message: message)
          return .none
        }

        let validationRequest = PaymentValidationRequest(imp_uid: impUID)
        let commerceClient = commerceClient

        return .run { send in
          await send(
            .paymentValidated(
              Result {
                try await commerceClient.validatePayment(validationRequest)
              }
            )
          )
        }
        .cancellable(id: "HomeDetailFeature.validatePayment", cancelInFlight: true)

      case .paymentValidated(.success):
        state.isPurchaseInFlight = false

        // 서버의 결제/다운로드 권한 상태를 진실의 출처로 삼아 상세 데이터를 재조회한다.
        // detailResponse 흐름을 재활용해 isPurchased(서버 is_downloaded)를 포함한 전 필드를 갱신.
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

      case let .paymentValidated(.failure(error)):
        state.isPurchaseInFlight = false
        state.alert = Self.makePurchaseFailureAlert(message: error.userFacingMessage)
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
    .ifLet(\.$alert, action: \.alert)
  }

  /// 결제 실패/취소를 사용자에게 안내하는 표준 AlertState 생성.
  private static func makePurchaseFailureAlert(message: String) -> AlertState<Action.Alert> {
    AlertState {
      TextState("결제에 실패했어요")
    } actions: {
      ButtonState(role: .cancel) {
        TextState("확인")
      }
    } message: {
      TextState(message)
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

  mutating func applyLikeStatus(_ status: Bool) {
    guard isLiked != status else { return }

    isLiked = status
    likeCount = max(0, (likeCount ?? 0) + (status ? 1 : -1))
  }
}

struct HomeDetailLikeSnapshot: Equatable, Sendable {
  let isLiked: Bool
  let likeCount: Int?
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
