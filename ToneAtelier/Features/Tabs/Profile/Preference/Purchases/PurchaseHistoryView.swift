//
//  PurchaseHistoryView.swift
//  ToneAtelier
//
//  Created by Codex on 5/2/26.
//

import ComposableArchitecture
import SwiftUI

struct PurchaseHistoryView: View {
  @Bindable var store: StoreOf<PurchaseHistoryFeature>
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    ScrollView {
      VStack(spacing: 0) {
        PurchaseHistoryHeader { dismiss() }

        VStack(alignment: .leading, spacing: 10) {
          contentBody
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, MainTabBarView.Layout.contentInsetHeight + 32)
      }
    }
    .scrollIndicators(.hidden)
    .background(AppTheme.background.ignoresSafeArea())
    .toolbar(.hidden, for: .navigationBar)
    .task { await store.send(.task).finish() }
    .sheet(
      isPresented: Binding(
        get: { store.receipt != nil },
        set: { isPresented in
          if !isPresented { store.send(.receiptDismissed) }
        }
      )
    ) {
      if let receipt = store.receipt {
        ReceiptSheet(state: receipt)
          .presentationDetents([.medium, .large])
          .presentationDragIndicator(.visible)
          .presentationBackground(AppTheme.background)
      }
    }
  }

  @ViewBuilder
  private var contentBody: some View {
    if store.isLoading && !store.hasLoaded {
      loadingView
    } else if let message = store.errorMessage, !store.hasLoaded {
      retryView(message: message)
    } else if store.orders.isEmpty {
      emptyView
    } else {
      LazyVStack(spacing: 10) {
        ForEach(store.orders, id: \.orderID) { order in
          PurchaseItemCard(order: order) {
            store.send(.orderTapped(orderID: order.orderID))
          }
        }
      }
    }
  }

  private var loadingView: some View {
    VStack(spacing: 14) {
      ProgressView().tint(AppTheme.gray45)
      Text("구매 내역을 불러오는 중입니다.")
        .pretendard(.body3)
        .foregroundStyle(AppTheme.gray60)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 60)
  }

  private func retryView(message: String) -> some View {
    VStack(spacing: 12) {
      Text(message)
        .pretendard(.body3)
        .foregroundStyle(AppTheme.gray60)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 24)

      Button("다시 시도") {
        store.send(.retryButtonTapped)
      }
      .pretendard(.body3Bold)
      .foregroundStyle(AppTheme.gray30)
      .frame(height: 36)
      .padding(.horizontal, 18)
      .background(AppTheme.deepTurquoise)
      .clipShape(Capsule())
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 40)
  }

  private var emptyView: some View {
    VStack(spacing: 6) {
      Text("구매 내역이 없습니다")
        .pretendard(.body2)
        .foregroundStyle(AppTheme.gray45)
      Text("필터팩이나 영상 효과를 구매하면 이곳에 표시됩니다.")
        .pretendard(.caption1)
        .foregroundStyle(AppTheme.gray60)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 40)
  }
}

// MARK: - Header

private struct PurchaseHistoryHeader: View {
  let onBack: () -> Void

  var body: some View {
    HStack(spacing: 0) {
      Button(action: onBack) {
        Image(systemName: "chevron.left")
          .font(AppTheme.symbol(size: 20, weight: .medium))
          .foregroundStyle(AppTheme.gray60)
          .frame(width: 48, height: 48)
          .contentShape(.rect)
      }
      .buttonStyle(.plain)
      .accessibilityLabel("뒤로")

      Spacer(minLength: 0)

      Color.clear.frame(width: 48, height: 48)
    }
    .overlay {
      Text("PURCHASES")
        .mulgyeol(.bodyNormal)
        .foregroundStyle(AppTheme.gray60)
        .accessibilityAddTraits(.isHeader)
    }
    .frame(height: 56)
    .padding(.horizontal, 20)
  }
}

// MARK: - Item Card

private struct PurchaseItemCard: View {
  let order: OrderResponseDTO
  let onTap: () -> Void

  var body: some View {
    Button(action: onTap) {
      HStack(spacing: 12) {
        Image(systemName: "sparkles")
          .font(AppTheme.symbol(size: 22, weight: .medium))
          .foregroundStyle(AppTheme.gray60)
          .frame(width: 22, height: 22)

        VStack(alignment: .leading, spacing: 4) {
          Text(title)
            .pretendard(.body3Bold)
            .foregroundStyle(AppTheme.gray30)
            .lineLimit(1)

          HStack(spacing: 6) {
            Text(dateText)
            if !priceText.isEmpty {
              Text("·")
              Text(priceText)
            }
          }
          .pretendard(.captionMeta)
          .foregroundStyle(AppTheme.gray75)
        }

        Spacer(minLength: 0)

        Image(systemName: "chevron.right")
          .font(AppTheme.symbol(size: 18, weight: .medium))
          .foregroundStyle(AppTheme.gray75)
      }
      .padding(14)
      .frame(height: 74)
      .background(
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .fill(AppTheme.blackTurquoise)
      )
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
  }

  private var title: String {
    let raw = order.filter?.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return raw.isEmpty ? "필터팩" : raw
  }

  private var dateText: String {
    PurchaseDateFormatter.shared.format(order.paidAt ?? order.createdAt)
  }

  private var priceText: String {
    guard let total = order.totalPrice else { return "" }
    return "₩\(PurchaseDateFormatter.shared.formatCurrency(total))"
  }
}

// MARK: - Receipt Sheet

private struct ReceiptSheet: View {
  let state: PurchaseHistoryFeature.ReceiptState

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      headerRow
      Divider().background(AppTheme.deepTurquoise)
      contentBody
      Spacer(minLength: 0)
    }
    .padding(20)
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var headerRow: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text("결제 영수증")
        .mulgyeol(.smallTitle)
        .foregroundStyle(AppTheme.gray30)
      Text(state.order.filter?.title ?? "필터팩")
        .pretendard(.captionBold)
        .foregroundStyle(AppTheme.gray60)
    }
  }

  @ViewBuilder
  private var contentBody: some View {
    if state.isLoading {
      HStack {
        Spacer()
        ProgressView().tint(AppTheme.gray45)
        Spacer()
      }
      .padding(.vertical, 30)
    } else if let message = state.errorMessage {
      Text(message)
        .pretendard(.body3)
        .foregroundStyle(AppTheme.gray60)
        .multilineTextAlignment(.leading)
    } else if let payment = state.payment {
      VStack(alignment: .leading, spacing: 10) {
        receiptRow("상품명", payment.name ?? state.order.filter?.title ?? "-")
        receiptRow("결제수단", payment.cardName ?? payment.payMethod ?? "-")
        receiptRow("결제 금액", "\(payment.currency) \(PurchaseDateFormatter.shared.formatCurrency(payment.amount))")
        let paidAt = payment.paidAt ?? state.order.paidAt ?? state.order.createdAt
        receiptRow("결제일", PurchaseDateFormatter.shared.format(paidAt))
      }
    }
  }

  private func receiptRow(_ label: String, _ value: String) -> some View {
    HStack(spacing: 12) {
      Text(label)
        .pretendard(.caption1)
        .foregroundStyle(AppTheme.gray60)
        .frame(width: 80, alignment: .leading)
      Text(value)
        .pretendard(.body3Bold)
        .foregroundStyle(AppTheme.gray30)
        .lineLimit(1)
        .truncationMode(.middle)
      Spacer(minLength: 0)
    }
  }

}

// MARK: - Formatter

/// 구매 화면 전용 날짜/통화 포맷터. 다른 화면이 동일 포맷을 요구하면
/// `Shared/Formatters`로 승격하지만, 현재는 단일 화면에서만 쓰여 fileprivate 스코프.
private final class PurchaseDateFormatter: @unchecked Sendable {
  static let shared = PurchaseDateFormatter()

  private let isoFormatter: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
  }()

  private let isoFormatterFallback: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime]
    return f
  }()

  private let displayFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyy.MM.dd"
    f.locale = Locale(identifier: "ko_KR")
    return f
  }()

  private let currencyFormatter: NumberFormatter = {
    let f = NumberFormatter()
    f.numberStyle = .decimal
    f.groupingSeparator = ","
    return f
  }()

  func format(_ raw: String) -> String {
    if let date = isoFormatter.date(from: raw) ?? isoFormatterFallback.date(from: raw) {
      return displayFormatter.string(from: date)
    }
    // 파싱 실패 시 prefix 10자만 표시 (yyyy-MM-dd → yyyy.MM.dd 보정).
    return raw.prefix(10).replacingOccurrences(of: "-", with: ".")
  }

  func formatCurrency(_ value: Int) -> String {
    currencyFormatter.string(from: NSNumber(value: value)) ?? String(value)
  }
}

#Preview {
  NavigationStack {
    PurchaseHistoryView(
      store: Store(initialState: PurchaseHistoryFeature.State()) {
        PurchaseHistoryFeature()
      }
    )
  }
  .preferredColorScheme(.dark)
}
