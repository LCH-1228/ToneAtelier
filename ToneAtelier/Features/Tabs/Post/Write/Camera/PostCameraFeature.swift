//
//  PostCameraFeature.swift
//  ToneAtelier
//
//  Pencil node: z8RX6L (Post Custom Camera View)
//

import ComposableArchitecture
import Foundation
import OSLog
import SwiftUI

@Reducer
struct PostCameraFeature {
  @Dependency(\.commerceClient) private var commerceClient
  @Dependency(\.filterClient) private var filterClient
  @Dependency(\.sessionClient) private var sessionClient

  @ObservableState
  struct State: Equatable {
    /// 내가 생성한 필터 (FilterClient.userFilters with currentUserID).
    var createdFilters: [PostCameraFilter] = []
    /// 구입한 필터 (CommerceClient.fetchOrders).
    var purchasedFilters: [PostCameraFilter] = []

    var isLoadingCreated = false
    var isLoadingPurchased = false

    var loadCreatedError: String?
    var loadPurchasedError: String?

    /// FilterClient.detail 으로 lazy 로 채우는 filterValues 캐시.
    /// summary API 응답에는 filterValues 가 없어 cell 의 실제 필터 효과 미리보기를 위해 detail 호출이 필요.
    var filterDetailsCache: [String: MakeFilterValues] = [:]

    /// nil 이면 "원본" 칩 선택 상태.
    var selectedFilter: PostCameraFilter?

    /// 필터 강도 슬라이더 0...1. 1.0 = 필터 완전 적용.
    var filterIntensity: Double = 1.0

    /// 분할 비교 핸들의 좌측 원본 / 우측 필터 경계 위치(고정 약 63%, pencil 디자인 기준).
    var splitFraction: Double = 0.633

    var flashMode: PostCameraFlashMode = .off
    var cameraPosition: PostCameraPosition = .back
    var cameraMode: PostCameraMode = .photo

    /// 첫 보고 전 안전 기본값 — wide 단일.
    var availableZoomPresets: [PostCameraZoomPreset] = [.wide]
    var selectedZoomPreset: PostCameraZoomPreset = .wide

    /// 사용자가 preview 에서 탭한 focus + exposure 지점. 자동으로 ~3초 후 사라진다.
    var focusIndicator: PostCameraFocus?
    /// EV bias. -2.0 ... +2.0 (device clamp). focus 새로 잡으면 0 reset.
    var exposureBias: Float = 0

    /// 필터 시트 표시 여부.
    var isSheetPresented = false
    var sheetTab: PostCameraSheetTab = .all

    var isCapturing = false
    var captureError: String?

    /// 전체 = 내 필터 ∪ 구입한 필터 (id 기준 dedupe, 내 필터 우선).
    var unionedFilters: [PostCameraFilter] {
      var seen = Set<String>()
      var result: [PostCameraFilter] = []
      for filter in createdFilters + purchasedFilters where seen.insert(filter.id).inserted {
        result.append(filter)
      }
      return result
    }

    var sheetVisibleFilters: [PostCameraFilter] {
      switch sheetTab {
      case .all: return unionedFilters
      case .created: return createdFilters
      case .purchased: return purchasedFilters
      }
    }

    var allTabCount: Int { unionedFilters.count }
    var createdTabCount: Int { createdFilters.count }
    var purchasedTabCount: Int { purchasedFilters.count }
  }

  enum Action: BindableAction, Sendable {
    case binding(BindingAction<State>)
    case task

    case loadCreatedFilters
    case createdFiltersResponse(Result<[PostCameraFilter], Error>)
    case loadPurchasedFilters
    case purchasedFiltersResponse(Result<[PostCameraFilter], Error>)
    case loadFilterDetail(filterID: String)
    case filterDetailResponse(filterID: String, Result<MakeFilterValues, Error>)

    case filterChipTapped(PostCameraFilter?)
    case intensityChanged(Double)
    case splitFractionChanged(Double)
    case flashTapped
    case flipTapped
    case modeTapped(PostCameraMode)
    case zoomPresetsReported([PostCameraZoomPreset])
    case zoomPresetTapped(PostCameraZoomPreset)
    case previewTapped(at: CGPoint)
    case focusIndicatorExpired(id: UUID)
    case exposureBiasChanged(Float)
    case sheetOpenTapped
    case sheetDismissed
    case sheetTabTapped(PostCameraSheetTab)

    case shutterTapped
    case captureResponse(Result<Data, Error>)

    case closeTapped
    case galleryTapped

    case delegate(Delegate)

    enum Delegate: Equatable, Sendable {
      case dismiss
      case captured(PostWriteFeature.PendingAttachment)
      case requestGalleryPicker
    }
  }

  /// 라이브 프리뷰에 적용할 최종 filterValues — 선택 필터 × 강도 슬라이더로 보간.
  static func resolvedFilterValues(state: State) -> MakeFilterValues {
    guard let target = state.selectedFilter?.filterValues else {
      return MakeFilterValues.default
    }
    return target.intensityScaled(state.filterIntensity)
  }

  var body: some Reducer<State, Action> {
    BindingReducer()
    Reduce { state, action in
      switch action {
      case .binding:
        return .none

      case .task:
        return .merge(
          .send(.loadCreatedFilters),
          .send(.loadPurchasedFilters)
        )

      case .loadCreatedFilters:
        guard !state.isLoadingCreated, state.createdFilters.isEmpty else { return .none }
        state.isLoadingCreated = true
        state.loadCreatedError = nil
        let filterClient = filterClient
        let sessionClient = sessionClient
        return .run { send in
          let snapshot = await sessionClient.snapshot()
          guard let userID = snapshot.currentUserID, !userID.isEmpty else {
            await send(.createdFiltersResponse(.success([])))
            return
          }
          await send(
            .createdFiltersResponse(
              Result {
                let response = try await filterClient.userFilters(
                  userID,
                  UserFilterListQuery(next: nil, limit: 50, category: nil)
                )
                return PostCameraFilter.from(summaries: response.data, isOwned: true)
              }
            )
          )
        }
        .cancellable(id: "PostCameraFeature.listCreated", cancelInFlight: true)

      case let .createdFiltersResponse(.success(filters)):
        state.isLoadingCreated = false
        state.createdFilters = filters
        return .none

      case let .createdFiltersResponse(.failure(error)):
        state.isLoadingCreated = false
        state.loadCreatedError = Self.userFacingMessage(for: error)
        Logger.postCamera.error("userFilters failed: \(error.localizedDescription, privacy: .public)")
        return .none

      case .loadPurchasedFilters:
        guard !state.isLoadingPurchased, state.purchasedFilters.isEmpty else { return .none }
        state.isLoadingPurchased = true
        state.loadPurchasedError = nil
        let commerceClient = commerceClient
        return .run { send in
          await send(
            .purchasedFiltersResponse(
              Result {
                let response = try await commerceClient.fetchOrders()
                return PostCameraFilter.from(orders: response.data)
              }
            )
          )
        }
        .cancellable(id: "PostCameraFeature.fetchOrders", cancelInFlight: true)

      case let .purchasedFiltersResponse(.success(filters)):
        state.isLoadingPurchased = false
        state.purchasedFilters = filters
        return .none

      case let .purchasedFiltersResponse(.failure(error)):
        state.isLoadingPurchased = false
        state.loadPurchasedError = Self.userFacingMessage(for: error)
        Logger.postCamera.error("fetchOrders failed: \(error.localizedDescription, privacy: .public)")
        return .none

      case let .loadFilterDetail(filterID):
        guard state.filterDetailsCache[filterID] == nil else { return .none }
        let filterClient = filterClient
        return .run { send in
          await send(
            .filterDetailResponse(
              filterID: filterID,
              Result {
                let detail = try await filterClient.detail(filterID)
                return MakeFilterValues(dto: detail.filterValues)
              }
            )
          )
        }
        .cancellable(id: "PostCameraFeature.detail.\(filterID)", cancelInFlight: false)

      case let .filterDetailResponse(filterID, .success(values)):
        state.filterDetailsCache[filterID] = values
        return .none

      case let .filterDetailResponse(filterID, .failure(error)):
        Logger.postCamera.error(
          "detail \(filterID, privacy: .public) failed: \(error.localizedDescription, privacy: .public)"
        )
        return .none

      case let .filterChipTapped(filter):
        if let filter, state.selectedFilter?.id == filter.id {
          state.selectedFilter = nil
        } else {
          state.selectedFilter = filter
        }
        return .none

      case let .intensityChanged(value):
        state.filterIntensity = max(0, min(1, value))
        return .none

      case let .splitFractionChanged(value):
        state.splitFraction = max(0, min(1, value))
        return .none

      case .flashTapped:
        state.flashMode = state.flashMode.next
        return .none

      case .flipTapped:
        state.cameraPosition.toggle()
        state.selectedZoomPreset = .wide
        return .none

      case let .modeTapped(mode):
        state.cameraMode = mode
        return .none

      case let .zoomPresetsReported(presets):
        state.availableZoomPresets = presets
        if !presets.contains(state.selectedZoomPreset) {
          state.selectedZoomPreset = .wide
        }
        return .none

      case let .zoomPresetTapped(preset):
        guard state.availableZoomPresets.contains(preset) else { return .none }
        state.selectedZoomPreset = preset
        return .none

      case let .previewTapped(point):
        let id = UUID()
        state.focusIndicator = PostCameraFocus(id: id, normalizedPoint: point)
        state.exposureBias = 0
        return .run { send in
          try? await Task.sleep(for: .seconds(3))
          await send(.focusIndicatorExpired(id: id))
        }
        .cancellable(id: "PostCameraFeature.focusFade.\(id.uuidString)", cancelInFlight: false)

      case let .focusIndicatorExpired(id):
        if state.focusIndicator?.id == id {
          state.focusIndicator = nil
          state.exposureBias = 0
        }
        return .none

      case let .exposureBiasChanged(bias):
        state.exposureBias = max(-2, min(2, bias))
        return .none

      case .sheetOpenTapped:
        state.isSheetPresented = true
        return .none

      case .sheetDismissed:
        state.isSheetPresented = false
        return .none

      case let .sheetTabTapped(tab):
        state.sheetTab = tab
        switch tab {
        case .all:
          return .none
        case .created:
          return state.createdFilters.isEmpty ? .send(.loadCreatedFilters) : .none
        case .purchased:
          return state.purchasedFilters.isEmpty ? .send(.loadPurchasedFilters) : .none
        }

      case .shutterTapped:
        state.isCapturing = true
        state.captureError = nil
        return .none

      case let .captureResponse(.success(data)):
        state.isCapturing = false
        state.captureError = nil
        return .send(
          .delegate(
            .captured(
              PostWriteFeature.PendingAttachment(
                fileName: PostCameraNaming.captureFileName(),
                mimeType: "image/jpeg",
                data: data
              )
            )
          )
        )

      case let .captureResponse(.failure(error)):
        state.isCapturing = false
        state.captureError = Self.userFacingMessage(for: error)
        Logger.postCamera.error("capture failed: \(error.localizedDescription, privacy: .public)")
        return .none

      case .closeTapped:
        return .send(.delegate(.dismiss))

      case .galleryTapped:
        return .send(.delegate(.requestGalleryPicker))

      case .delegate:
        return .none
      }
    }
  }
}

private extension PostCameraFlashMode {
  var next: PostCameraFlashMode {
    switch self {
    case .off: return .on
    case .on: return .auto
    case .auto: return .off
    }
  }
}

private enum PostCameraNaming {
  nonisolated static func captureFileName() -> String {
    let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "")
    return "camera_\(stamp).jpg"
  }
}

extension PostCameraFilter {
  /// 주문 내역 → 구입한 필터 목록. 동일 filter id 중복은 제거, paidAt 또는 createdAt 기준 최신순.
  nonisolated static func from(orders: [OrderResponseDTO]) -> [PostCameraFilter] {
    var seen = Set<String>()
    var items: [PostCameraFilter] = []
    let sorted = orders.sorted { lhs, rhs in
      (lhs.paidAt ?? lhs.createdAt) > (rhs.paidAt ?? rhs.createdAt)
    }
    for order in sorted {
      guard
        let summary = order.filter,
        let filterID = summary.id,
        !seen.contains(filterID)
      else { continue }
      seen.insert(filterID)
      let values = summary.filterValues.map(MakeFilterValues.init(dto:)) ?? .default
      items.append(
        PostCameraFilter(
          id: filterID,
          title: summary.title ?? "필터",
          previewImagePath: summary.files?.first,
          filterValues: values,
          isOwned: true,
          price: nil,
          swatchColor: Color(red: 0.49, green: 0.49, blue: 0.49)
        )
      )
    }
    return items
  }

  /// FilterSummary 응답 → PostCameraFilter. summary 에는 filterValues 가 없으므로 .default.
  /// cell 미리보기는 previewImagePath 폴백 이미지를 노출한다.
  nonisolated static func from(
    summaries: [FilterSummaryResponseDTO],
    isOwned: Bool
  ) -> [PostCameraFilter] {
    summaries.map { summary in
      PostCameraFilter(
        id: summary.filterID,
        title: summary.title,
        previewImagePath: summary.files.first,
        filterValues: .default,
        isOwned: isOwned,
        price: nil,
        swatchColor: Color(red: 0.49, green: 0.49, blue: 0.49)
      )
    }
  }
}

private extension PostCameraFeature {
  static func userFacingMessage(for error: Error) -> String {
    if let apiError = error as? APIError {
      switch apiError {
      case let .invalidBaseURL(message),
           let .invalidURL(message),
           let .transport(message),
           let .decoding(message):
        return message

      case .missingAccessToken, .missingRefreshToken:
        return "인증 정보가 없어 보유 필터를 불러올 수 없어요."

      case let .invalidSession(statusCode):
        return "세션이 유효하지 않습니다. 다시 로그인해 주세요. (\(statusCode))"

      case let .server(statusCode, message, _):
        if let message, !message.isEmpty { return message }
        return "보유 필터를 불러오지 못했어요. (\(statusCode))"
      }
    }
    return "잠시 후 다시 시도해 주세요."
  }
}
