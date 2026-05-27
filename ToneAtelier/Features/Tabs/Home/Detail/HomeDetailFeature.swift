//
//  HomeDetailFeature.swift
//  ToneAtelier
//
//  Created by Codex on 4/25/26.
//

// swiftlint:disable file_length
// 필터 상세 + 결제 흐름이 한 reducer에 묶여 있어 외부 분리해도 의미 있는 경계가 안 생김.

import ComposableArchitecture
import Foundation
import OSLog

@Reducer
// swiftlint:disable:next type_body_length
struct HomeDetailFeature {
  @Dependency(\.homeDetailClient) private var homeDetailClient
  @Dependency(\.commerceClient) private var commerceClient
  @Dependency(\.filterClient) private var filterClient
  @Dependency(\.paymentReceiptStore) private var paymentReceiptStore
  @Dependency(\.sessionClient) private var sessionClient
  @Dependency(\.toastClient) private var toastClient
  @Dependency(\.userClient) private var userClient

  /// 결제 흐름 디버깅용 로거. 외부 분석 SDK 없이 OS 표준 Logger로
  /// 단계별 진행/실패만 남기며, 가격·사용자 ID 등 PII 가능 데이터는 기록하지 않는다.
  /// release 빌드에서는 `.disabled` Logger로 교체되어 식별자 평문 노출 위험을 차단한다.
  /// (DEBUG 한정 가드 위에서 식별자 보간에 `privacy: .public`을 명시해 redact를 푼다.)
  private static let paymentLogger: Logger = {
#if DEBUG
    Logger(subsystem: "com.mitti.ToneAtelier", category: "Payment")
#else
    Logger(.disabled)
#endif
  }()

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
    var authorUserID: String = ""
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
    /// validatePayment 재시도용 impUID. paymentCompleted.success 시 set, validate 성공 시 reset.
    var lastValidatedImpUID: String?
    /// receipt store 미완 entry cleanup 용 merchantUID. paymentCompleted.success 시 set.
    var lastValidatedMerchantUID: String?
    /// 현재 결제 시도에서 자동 reconcile (validatePayment 재호출) 이미 1회 수행했는지.
    /// 새 결제 시도(`purchaseButtonTapped`) 마다 false 로 reset.
    var didReconcileValidate = false
    /// 알림 액션의 "문의" 가 트리거되면 set. View 가 onChange 로 openURL 후 `mailtoConsumed` 로 nil 리셋.
    var pendingMailtoURL: URL?
    /// 결제 실패 등 사용자에게 즉시 노출할 알림.
    @Presents var alert: AlertState<Action.Alert>?
    var comments: [FilterCommentResponseDTO] = []
    var commentInput: String = ""
    var replyTargetCommentID: String?
    var replyTargetNickname: String?
    var isCommentSubmitting: Bool = false
    var editingCommentID: String?
    var currentUserID: String?

    init(
      id: String,
      title: String,
      summary: String?,
      likeCount: Int?,
      imageURL: String? = nil,
      isPurchased: Bool = false,
      authorUserID: String = ""
    ) {
      self.id = id
      self.title = title
      self.summary = summary
      self.likeCount = likeCount
      // 상세 로드 전에는 placeholder 금액으로 결제가 시작되지 않도록 0으로 둔다.
      // 실제 값은 detailResponse(.success) → apply(_:)에서 서버 데이터로 채워진다.
      self.price = 0
      self.buyerCount = 0
      self.isLiked = false
      self.isPurchased = isPurchased
      self.afterImageURL = imageURL
      self.beforeImageURL = imageURL
      self.authorUserID = authorUserID
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
        imageURL: trend.imageURL,
        authorUserID: trend.authorUserID
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

    init(profileFeaturedFilter filter: FeaturedFilter) {
      self.init(
        id: filter.id,
        title: filter.name,
        summary: filter.description,
        likeCount: nil,
        imageURL: filter.thumbnailURL,
        authorUserID: filter.authorUserID
      )
    }

    init(likedFilter filter: LikedFilter) {
      self.init(
        id: filter.id,
        title: filter.title,
        summary: filter.description.isEmpty ? nil : filter.description,
        likeCount: filter.likeCount,
        imageURL: filter.coverURL,
        authorUserID: filter.authorUserID
      )
    }

    init(creatorStoreItem item: CreatorStoreItem) {
      self.init(
        id: item.id,
        title: item.title,
        summary: item.description.isEmpty ? nil : item.description,
        likeCount: item.likeCount,
        imageURL: item.imageURL,
        authorUserID: item.authorUserID
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
    case orderCreated(Result<OrderCreatedResponse, Error>, buyerProfile: MyInfoResponseDTO?)
    case paymentSheetDismissed
    case paymentCompleted(IamportPaymentResult)
    case paymentValidated(Result<ReceiptOrderResponseDTO, Error>)
    /// validatePayment 가 transport/server 실패한 직후 1회 자동 재시도.
    case reconcileValidatePayment(impUID: String)
    /// 영수증을 첨부한 mailto URL 준비 완료 — state.pendingMailtoURL 에 set.
    case mailtoPrepared(URL?)
    /// View 가 mailto URL 을 처리한 후 호출 — pendingMailtoURL 을 nil 로 리셋.
    case mailtoConsumed
    /// 결제 검증 성공 직후 서버 권한/상태를 재조회한 응답.
    /// 일반 detailResponse와 분리해 실패 시 "결제는 성공했지만 갱신만 실패" 안내를 따로 처리한다.
    case purchaseRefreshResponse(Result<HomeDetailLoadedData, Error>)
    case commentInputChanged(String)
    case commentRowTapped(commentID: String, nickname: String)
    case replyDismissTapped
    case commentSubmitTapped
    case createCommentResponse(Result<FilterCommentResponseDTO, Error>)
    case commentEditTapped(commentID: String, currentContent: String)
    case commentDeleteTapped(commentID: String)
    case updateCommentResponse(commentID: String, Result<FilterCommentResponseDTO, Error>)
    case deleteCommentResponse(commentID: String, Result<EmptyResponse, Error>)
    case currentUserResolved(String?)
    case task
    case authorProfileTapped
    case authorMessageTapped

    enum Alert: Equatable, Sendable {
      case retryPurchaseTapped
      /// "문의" 버튼. reducer 가 mailto URL 을 만들어 state.pendingMailtoURL 에 set.
      case customerSupportTapped
    }

    enum Delegate: Equatable, Sendable {
      case likeStatusChanged(id: String, isLiked: Bool, likeCount: Int?)
      /// 작성자 프로필 진입. 부모가 path 에 .userProfile 을 push 한다.
      case userProfileRequested(userID: String, nick: String, introduction: String?, profileImage: String?)
      /// 작성자에게 메시지 보내기. cross-tab 으로 chat 탭 + chatRoom push.
      case messageRequested(userID: String, nick: String, introduction: String?, profileImage: String?)
    }
  }

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .alert(.presented(.retryPurchaseTapped)):
        // 결제 실패 alert에서 "다시 시도"를 누른 경우 결제 흐름을 재진입한다.
        // purchaseButtonTapped 내부의 가드(이미 구매/진행 중/가격 0 등)를 그대로 재사용하므로
        // 별도 상태 정리 없이 곧바로 재시도 effect를 발사한다.
        return .send(.purchaseButtonTapped)

      case .alert(.presented(.customerSupportTapped)):
        let paymentReceiptStore = paymentReceiptStore
        return .run { send in
          let receipts = await paymentReceiptStore.loadAll()
          await send(.mailtoPrepared(Self.makeSupportMailtoURL(receipts: receipts)))
        }

      case let .mailtoPrepared(url):
        state.pendingMailtoURL = url
        return .none

      case .mailtoConsumed:
        state.pendingMailtoURL = nil
        return .none

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

      case .authorProfileTapped:
        guard !state.authorUserID.isEmpty else { return .none }
        return .send(
          .delegate(
            .userProfileRequested(
              userID: state.authorUserID,
              nick: state.authorName,
              introduction: state.authorSubtitle,
              profileImage: state.authorProfileImageURL
            )
          )
        )

      case .authorMessageTapped:
        guard !state.authorUserID.isEmpty else { return .none }
        return .send(
          .delegate(
            .messageRequested(
              userID: state.authorUserID,
              nick: state.authorName,
              introduction: state.authorSubtitle,
              profileImage: state.authorProfileImageURL
            )
          )
        )

      case .delegate:
        return .none

      case .likeButtonTapped:
        return handleLikeButtonTapped(state: &state)

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
        let toastClient = self.toastClient
        return .merge(
          .send(
            .delegate(
              .likeStatusChanged(
                id: state.id,
                isLiked: state.isLiked,
                likeCount: state.likeCount
              )
            )
          ),
          .run { _ in await toastClient.show("좋아요 처리에 실패했어요. 잠시 후 다시 시도해 주세요.") }
        )

      case .noop:
        return .none

      // MARK: - 결제 흐름
      case .purchaseButtonTapped:
        return handlePurchaseButtonTapped(state: &state)

      case let .orderCreated(.success(response), buyerProfile):
        // 사용자가 이미 흐름을 취소(시트 dismiss)한 뒤 도착한 늦은 응답은 무시한다.
        guard state.isPurchaseInFlight else {
          return .none
        }
        Self.paymentLogger.debug("order created — orderCode=\(response.orderCode, privacy: .public)")
        // 주문 생성 성공 → 결제 시트 트리거. 콜백 가드용으로 merchantUID도 보관.
        state.pendingPaymentMerchantUID = response.orderCode
        // buyer 정보: PG 영수증 페이지의 본인 확인 매칭 (이름/이메일/휴대폰 중 하나).
        // 회원 정보 fetch 실패 시 빈 문자열 — 결제 자체는 진행, 영수증 페이지 입력만 어려움.
        state.activePayment = IamportPaymentRequest(
          merchantUID: response.orderCode,
          amount: state.price,
          name: state.title,
          appScheme: AppURLScheme.payment,
          buyerName: buyerProfile?.name ?? buyerProfile?.nick ?? "",
          buyerEmail: buyerProfile?.email ?? "",
          buyerTel: buyerProfile?.phoneNum ?? ""
        )
        return .none

      case let .orderCreated(.failure(error), _):
        // 사용자가 이미 흐름을 취소했다면 알림을 띄우지 않는다.
        guard state.isPurchaseInFlight else {
          return .none
        }
        Self.paymentLogger.error("order failed — \(error.localizedDescription, privacy: .public)")
        state.isPurchaseInFlight = false
        state.pendingPaymentMerchantUID = nil
        let isAuth = Self.isAuthError(error)
        state.alert = Self.makePurchaseFailureAlert(
          message: Self.purchaseFailureMessage(from: error),
          allowRetry: !isAuth,
          allowSupport: !isAuth
        )
        return .none

      case .paymentSheetDismissed:
        // reducer 주도 dismiss(paymentCompleted 등)에서는 pendingPaymentMerchantUID가 이미 nil로
        // 비워져 있으므로, 진행 중인 검증/주문 effect를 건드리지 않는다.
        // 사용자가 시스템 dismiss(스와이프 등)로 시트를 닫은 경우에만 정리 경로를 탄다.
        guard state.pendingPaymentMerchantUID != nil else {
          return .none
        }
        Self.paymentLogger.debug("payment sheet dismissed by user — cancel inflight")
        state.activePayment = nil
        state.isPurchaseInFlight = false
        state.pendingPaymentMerchantUID = nil
        return .merge(
          .cancel(id: "HomeDetailFeature.createOrder"),
          .cancel(id: "HomeDetailFeature.validatePayment")
        )

      case let .paymentCompleted(result):
        return handlePaymentCompleted(state: &state, result: result)

      case .paymentValidated(.success):
        // 서버가 ReceiptOrderResponseDTO로 200을 돌려준 시점에 검증이 성공한 것으로 간주한다.
        // (이전 JSONValue 시절의 status/success 키 방어 로직은 spec 응답에 해당 필드가 없어 제거)
        Self.paymentLogger.debug("payment validated — proceeding to refresh")
        state.isPurchaseInFlight = false
        state.lastValidatedImpUID = nil
        state.didReconcileValidate = false

        // 검증 성공 — 영수증 미완 entry 제거.
        let filterID = state.id
        let homeDetailClient = homeDetailClient
        let paymentReceiptStore = paymentReceiptStore
        let merchantUIDForCleanup = state.lastValidatedMerchantUID
        state.lastValidatedMerchantUID = nil

        return .run { send in
          if let merchantUID = merchantUIDForCleanup {
            await paymentReceiptStore.remove(merchantUID)
          }
          await send(
            .purchaseRefreshResponse(
              Result {
                try await homeDetailClient.fetchDetail(filterID)
              }
            )
          )
        }
        .cancellable(id: "HomeDetailFeature.purchaseRefresh", cancelInFlight: true)

      case let .purchaseRefreshResponse(.success(data)):
        Self.paymentLogger.debug("purchase refresh succeeded — isPurchased=\(data.isPurchased, privacy: .public)")
        // 결제 성공 + 갱신 성공. 일반 detailResponse(.success)와 동일한 적용.
        // errorMessage는 이전 에러가 남아 있을 수 있으니 명시적으로 비운다.
        state.isLoadingDetail = false
        state.hasLoadedDetail = true
        state.errorMessage = nil
        state.apply(data)
        // 결제 검증이 이미 성공한 경로이므로 서버 일관성 지연으로 false가 와도 클라가 true를 우선시한다.
        state.isPurchased = true
        return .none

      case let .purchaseRefreshResponse(.failure(error)):
        Self.paymentLogger.error("purchase refresh failed — \(error.localizedDescription, privacy: .public)")
        // 결제 자체는 성공한 상태에서 정보 갱신만 실패한 케이스.
        // 일반 detailResponse(.failure)로 흘려 errorMessage만 세팅하면 사용자가
        // "결제 실패"로 오해할 수 있어 별도 alert로 결제 성공 사실을 먼저 안내한다.
        state.alert = AlertState {
          TextState("결제가 완료되었어요")
        } actions: {
          ButtonState(role: .cancel) { TextState("확인") }
        } message: {
          TextState("정보 갱신에 잠시 문제가 있어 화면을 다시 들어와 주세요.")
        }
        return .none

      case let .paymentValidated(.failure(error)):
        Self.paymentLogger.error("payment validation failed — \(error.localizedDescription, privacy: .public)")
        // 인증 에러는 재시도해도 같은 결과이므로 reconcile/retry 모두 우회.
        if !Self.isAuthError(error),
           !state.didReconcileValidate,
           let impUID = state.lastValidatedImpUID {
          state.didReconcileValidate = true
          // isPurchaseInFlight 는 그대로 유지 — 사용자에게 "다시 시도 중" 으로 보임.
          Self.paymentLogger.debug("auto reconcile validatePayment in 3s")
          return .run { send in
            try? await Task.sleep(for: .seconds(3))
            await send(.reconcileValidatePayment(impUID: impUID))
          }
          .cancellable(id: "HomeDetailFeature.reconcile", cancelInFlight: true)
        }
        state.isPurchaseInFlight = false
        // 인증 에러는 retry 비활성, 그 외는 retry + 문의 모두 활성.
        let isAuth = Self.isAuthError(error)
        state.alert = Self.makePurchaseFailureAlert(
          message: Self.purchaseFailureMessage(from: error),
          allowRetry: !isAuth,
          allowSupport: !isAuth
        )
        return .none

      case let .reconcileValidatePayment(impUID):
        let validationRequest = PaymentValidationRequestDTO(impUID: impUID, filterID: state.id)
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

      case let .commentInputChanged(value):
        state.commentInput = value
        return .none

      case let .commentRowTapped(commentID, nickname):
        state.replyTargetCommentID = commentID
        state.replyTargetNickname = nickname
        return .none

      case .replyDismissTapped:
        state.replyTargetCommentID = nil
        state.replyTargetNickname = nil
        return .none

      case .commentSubmitTapped:
        if state.editingCommentID != nil {
          return handleCommentUpdateTapped(state: &state)
        }
        return handleCommentSubmitTapped(state: &state)

      case let .createCommentResponse(.success(response)):
        state.isCommentSubmitting = false
        state.commentInput = ""
        state.applyNewComment(response)
        state.replyTargetCommentID = nil
        state.replyTargetNickname = nil
        return .none

      case let .createCommentResponse(.failure(error)):
        state.isCommentSubmitting = false
        state.alert = AlertState {
          TextState("댓글 등록 실패")
        } actions: {
          ButtonState(role: .cancel) { TextState("확인") }
        } message: {
          TextState(error.userFacingMessage)
        }
        return .none

      case let .commentEditTapped(commentID, currentContent):
        state.editingCommentID = commentID
        state.commentInput = currentContent
        state.replyTargetCommentID = nil
        state.replyTargetNickname = nil
        return .none

      case let .commentDeleteTapped(commentID):
        return handleCommentDeleteTapped(state: &state, commentID: commentID)

      case let .updateCommentResponse(commentID, .success(response)):
        state.isCommentSubmitting = false
        state.editingCommentID = nil
        state.commentInput = ""
        state.applyUpdatedComment(commentID: commentID, response: response)
        return .none

      case let .updateCommentResponse(_, .failure(error)):
        state.isCommentSubmitting = false
        state.alert = AlertState {
          TextState("댓글 수정 실패")
        } actions: {
          ButtonState(role: .cancel) { TextState("확인") }
        } message: {
          TextState(error.userFacingMessage)
        }
        return .none

      case let .deleteCommentResponse(commentID, .success):
        state.removeComment(commentID: commentID)
        return .none

      case let .deleteCommentResponse(_, .failure(error)):
        state.alert = AlertState {
          TextState("댓글 삭제 실패")
        } actions: {
          ButtonState(role: .cancel) { TextState("확인") }
        } message: {
          TextState(error.userFacingMessage)
        }
        return .none

      case let .currentUserResolved(userID):
        state.currentUserID = userID
        return .none

      case .task:
        guard !state.hasLoadedDetail else { return .none }

        state.isLoadingDetail = true
        state.errorMessage = nil

        let filterID = state.id
        let homeDetailClient = homeDetailClient
        let sessionClient = sessionClient

        return .merge(
          .run { send in
            let snapshot = await sessionClient.snapshot()
            await send(.currentUserResolved(snapshot.currentUserID))
          },
          .run { send in
            await send(
              .detailResponse(
                Result {
                  try await homeDetailClient.fetchDetail(filterID)
                }
              )
            )
          }
          .cancellable(id: "HomeDetailFeature.detail", cancelInFlight: true)
        )
      }
    }
    .ifLet(\.$alert, action: \.alert)
  }

}

// MARK: - Effect handlers / Purchase helpers

private extension HomeDetailFeature {
  func handleLikeButtonTapped(state: inout State) -> Effect<Action> {
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
  }

  func handlePurchaseButtonTapped(state: inout State) -> Effect<Action> {
    // 상세 로드 전이거나 가격이 0 이하이면 placeholder 금액으로 주문이 생성되는 사고를 막는다.
    guard state.hasLoadedDetail, state.price > 0 else {
      return .none
    }
    // 이미 구매했거나 진행 중이면 무시.
    guard !state.isPurchased, !state.isPurchaseInFlight else {
      return .none
    }

    state.isPurchaseInFlight = true
    // 새 결제 시도이므로 reconcile flag 초기화 — 이전 시도의 잔재가 다음 시도를 막지 않게.
    state.didReconcileValidate = false
    state.lastValidatedImpUID = nil
    state.lastValidatedMerchantUID = nil

    let request = OrderCreateRequestDTO(filterID: state.id, totalPrice: state.price)
    let commerceClient = commerceClient
    let userClient = userClient
    let filterID = state.id
    Self.paymentLogger.debug("purchase started — filterID=\(filterID, privacy: .public)")

    return .run { send in
      // 주문 생성과 회원 정보 조회를 병렬로 — buyer 정보(PG 영수증 본인확인용)를 결제 요청에 포함.
      // profile fetch 실패는 silent — 결제 자체는 진행, buyer 필드만 빈 문자열 fallback.
      async let orderResult = Result { try await commerceClient.createOrder(request) }
      async let buyerProfile: MyInfoResponseDTO? = try? await userClient.fetchMyProfile()
      let (order, profile) = await (orderResult, buyerProfile)
      await send(.orderCreated(order, buyerProfile: profile))
    }
    .cancellable(id: "HomeDetailFeature.createOrder", cancelInFlight: true)
  }

  func handleCommentSubmitTapped(state: inout State) -> Effect<Action> {
    let trimmed = state.commentInput.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, !state.isCommentSubmitting else { return .none }
    state.isCommentSubmitting = true

    let filterID = state.id
    let request = CommentRequestDTO(
      parentCommentID: state.replyTargetCommentID,
      content: trimmed
    )
    let filterClient = filterClient

    return .run { send in
      await send(
        .createCommentResponse(
          Result { try await filterClient.createComment(filterID, request) }
        )
      )
    }
    .cancellable(id: "HomeDetailFeature.createComment", cancelInFlight: false)
  }

  func handleCommentUpdateTapped(state: inout State) -> Effect<Action> {
    let trimmed = state.commentInput.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty,
          !state.isCommentSubmitting,
          let commentID = state.editingCommentID
    else { return .none }
    state.isCommentSubmitting = true

    let filterID = state.id
    let request = CommentUpdateRequestDTO(content: trimmed)
    let filterClient = filterClient

    return .run { send in
      await send(
        .updateCommentResponse(
          commentID: commentID,
          Result { try await filterClient.updateComment(filterID, commentID, request) }
        )
      )
    }
    .cancellable(id: "HomeDetailFeature.updateComment.\(commentID)", cancelInFlight: false)
  }

  func handleCommentDeleteTapped(state: inout State, commentID: String) -> Effect<Action> {
    let filterID = state.id
    let filterClient = filterClient

    return .run { send in
      await send(
        .deleteCommentResponse(
          commentID: commentID,
          Result { try await filterClient.deleteComment(filterID, commentID) }
        )
      )
    }
    .cancellable(id: "HomeDetailFeature.deleteComment.\(commentID)", cancelInFlight: false)
  }

  func handlePaymentCompleted(
    state: inout State,
    result: IamportPaymentResult
  ) -> Effect<Action> {
    guard let merchantUID = state.pendingPaymentMerchantUID else {
      return .none
    }
    let impUIDLog = result.impUID ?? "nil"
    Self.paymentLogger.debug(
      "payment completed — success=\(result.success, privacy: .public), impUID=\(impUIDLog, privacy: .public)"
    )

    state.activePayment = nil
    state.pendingPaymentMerchantUID = nil

    guard result.success, let impUID = result.impUID else {
      state.isPurchaseInFlight = false
      // 사용자 취소는 silent (alert 미표시) — UX 노이즈 회피.
      if let message = result.errorMessage, !Self.isCancelMessage(message) {
        state.alert = Self.makePurchaseFailureAlert(
          message: message,
          allowRetry: true,
          allowSupport: true
        )
      } else if result.errorMessage == nil {
        // SDK 가 errorMessage 도 안 준 비정상 종료 — 안전 알림.
        state.alert = Self.makePurchaseFailureAlert(
          message: "결제 처리 중 문제가 발생했어요.",
          allowRetry: true,
          allowSupport: true
        )
      }
      return .none
    }

    state.lastValidatedImpUID = impUID
    state.lastValidatedMerchantUID = merchantUID
    let receipt = PaymentReceipt(
      merchantUID: merchantUID,
      impUID: impUID,
      filterID: state.id,
      createdAt: Date()
    )
    let validationRequest = PaymentValidationRequestDTO(impUID: impUID, filterID: state.id)
    let commerceClient = commerceClient
    let paymentReceiptStore = paymentReceiptStore

    return .run { send in
      // 영수증 정보 미리 저장 — validatePayment 실패해도 추후 reconcile/문의 가능.
      await paymentReceiptStore.record(receipt)
      await send(
        .paymentValidated(
          Result {
            try await commerceClient.validatePayment(validationRequest)
          }
        )
      )
    }
    .cancellable(id: "HomeDetailFeature.validatePayment", cancelInFlight: true)
  }

  /// 결제 실패/취소를 사용자에게 안내하는 표준 AlertState 생성.
  /// - Parameters:
  ///   - allowRetry: 토큰 만료 등 재시도해도 같은 결과가 예상되는 경우 false.
  ///   - allowSupport: 카드 거절·네트워크·서버 검증 실패 등 사용자 측 추적이 필요한 경우 true.
  static func makePurchaseFailureAlert(
    message: String,
    allowRetry: Bool = true,
    allowSupport: Bool = false
  ) -> AlertState<Action.Alert> {
    AlertState {
      TextState("결제에 실패했어요")
    } actions: {
      if allowRetry {
        ButtonState(action: .retryPurchaseTapped) {
          TextState("다시 시도")
        }
      }
      if allowSupport {
        ButtonState(action: .customerSupportTapped) {
          TextState("문의")
        }
      }
      ButtonState(role: .cancel) {
        TextState("닫기")
      }
    } message: {
      TextState(message)
    }
  }

  /// iamport SDK 가 사용자 취소 시 errorMessage 로 보내는 문구를 분류.
  /// 사용자 취소는 alert 미표시 (UX 노이즈 회피).
  static func isCancelMessage(_ message: String) -> Bool {
    let lowered = message.lowercased()
    return lowered.contains("취소") || lowered.contains("cancel")
  }

  /// 결제 문의용 mailto URL. 미완 영수증을 본문에 첨부해 고객지원이 PG 측 조회/수동 환불을 처리할 수 있게 한다.
  /// 영수증 없으면 본문 placeholder 만 둔다 (사용자가 직접 작성).
  static func makeSupportMailtoURL(receipts: [PaymentReceipt]) -> URL? {
    let subject = "[ToneAtelier] 결제 문의"
    var bodyLines: [String] = ["결제 관련 문의 사항을 적어 주세요.", "", "— 자동 첨부 (수정 금지) —"]
    if receipts.isEmpty {
      bodyLines.append("미완 영수증 없음")
    } else {
      for receipt in receipts {
        bodyLines.append("• 주문 ID: \(receipt.merchantUID)")
        if let imp = receipt.impUID { bodyLines.append("  결제 ID: \(imp)") }
        bodyLines.append("  필터 ID: \(receipt.filterID)")
        bodyLines.append("  시각: \(ISO8601DateFormatter().string(from: receipt.createdAt))")
        bodyLines.append("")
      }
    }
    let body = bodyLines.joined(separator: "\n")
    var components = URLComponents()
    components.scheme = "mailto"
    components.path = "support@toneatelier.app"
    components.queryItems = [
      URLQueryItem(name: "subject", value: subject),
      URLQueryItem(name: "body", value: body)
    ]
    return components.url
  }

  /// 결제 컨텍스트 메시지. 인증 관련 APIError는 결제 친화 문구로 교체.
  static func purchaseFailureMessage(from error: Error) -> String {
    if let apiError = error as? APIError {
      switch apiError {
      case .missingAccessToken, .missingRefreshToken, .invalidSession:
        return "로그인이 만료되었어요. 다시 로그인 후 시도해 주세요."
      default:
        break
      }
    }
    return error.userFacingMessage
  }

  /// 재시도해도 같은 결과가 예상되는 인증 에러인지.
  static func isAuthError(_ error: Error) -> Bool {
    if let apiError = error as? APIError {
      switch apiError {
      case .missingAccessToken, .missingRefreshToken, .invalidSession:
        return true
      default:
        return false
      }
    }
    return false
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
    authorUserID = data.authorUserID
    authorName = data.authorName
    authorSubtitle = data.authorSubtitle
    authorProfileImageURL = data.authorProfileImageURL
    authorTags = data.authorTags
    exif = data.exif
    presets = data.presets
    comments = data.comments
  }

  mutating func applyLikeStatus(_ status: Bool) {
    guard isLiked != status else { return }

    isLiked = status
    likeCount = max(0, (likeCount ?? 0) + (status ? 1 : -1))
  }

  /// 새 댓글/답글을 comments 에 반영. parentCommentID 가 있으면 해당 댓글의 replies 끝에 추가.
  mutating func applyNewComment(_ response: FilterCommentResponseDTO) {
    if let parentID = replyTargetCommentID,
       let parentIndex = comments.firstIndex(where: { $0.commentID == parentID }) {
      let parent = comments[parentIndex]
      let newReply = FilterCommentReplyDTO(
        commentID: response.commentID,
        content: response.content,
        createdAt: response.createdAt,
        creator: response.creator
      )
      comments[parentIndex] = FilterCommentResponseDTO(
        commentID: parent.commentID,
        content: parent.content,
        createdAt: parent.createdAt,
        creator: parent.creator,
        replies: parent.replies + [newReply]
      )
    } else {
      comments.append(response)
    }
  }

  /// 수정 응답을 받아 해당 댓글/답글의 content 만 갈아끼운다.
  mutating func applyUpdatedComment(commentID: String, response: FilterCommentResponseDTO) {
    if let index = comments.firstIndex(where: { $0.commentID == commentID }) {
      let original = comments[index]
      comments[index] = FilterCommentResponseDTO(
        commentID: original.commentID,
        content: response.content,
        createdAt: original.createdAt,
        creator: original.creator,
        replies: original.replies
      )
      return
    }
    for parentIndex in comments.indices {
      let parent = comments[parentIndex]
      if let replyIndex = parent.replies.firstIndex(where: { $0.commentID == commentID }) {
        let original = parent.replies[replyIndex]
        var newReplies = parent.replies
        newReplies[replyIndex] = FilterCommentReplyDTO(
          commentID: original.commentID,
          content: response.content,
          createdAt: original.createdAt,
          creator: original.creator
        )
        comments[parentIndex] = FilterCommentResponseDTO(
          commentID: parent.commentID,
          content: parent.content,
          createdAt: parent.createdAt,
          creator: parent.creator,
          replies: newReplies
        )
        return
      }
    }
  }

  /// 댓글/답글 삭제. 댓글 자체면 통째로, 답글이면 부모의 replies 에서 제거.
  mutating func removeComment(commentID: String) {
    if comments.contains(where: { $0.commentID == commentID }) {
      comments.removeAll { $0.commentID == commentID }
      return
    }
    for parentIndex in comments.indices {
      let parent = comments[parentIndex]
      if parent.replies.contains(where: { $0.commentID == commentID }) {
        comments[parentIndex] = FilterCommentResponseDTO(
          commentID: parent.commentID,
          content: parent.content,
          createdAt: parent.createdAt,
          creator: parent.creator,
          replies: parent.replies.filter { $0.commentID != commentID }
        )
        return
      }
    }
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
