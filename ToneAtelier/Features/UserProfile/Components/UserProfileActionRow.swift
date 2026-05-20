import SwiftUI

struct UserProfileActionRow: View {
  let isCreatingRoom: Bool
  let messageAction: () -> Void
  let storeAction: () -> Void

  var body: some View {
    HStack(spacing: 10) {
      Button(action: messageAction) {
        actionLabel(
          systemImage: "paperplane.fill",
          title: "메시지 보내기",
          foreground: AppTheme.gray30
        )
        .background(
          RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(AppTheme.brightTurquoise)
        )
      }
      .buttonStyle(.plain)
      .disabled(isCreatingRoom)

      Button(action: storeAction) {
        actionLabel(
          systemImage: "bag",
          title: "스토어 보기",
          foreground: AppTheme.gray60
        )
        .background(
          RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(AppTheme.blackTurquoise)
        )
        .overlay(
          RoundedRectangle(cornerRadius: 12, style: .continuous)
            .stroke(AppTheme.deepTurquoise, lineWidth: 1)
        )
      }
      .buttonStyle(.plain)
    }
    .frame(height: 44)
  }

  private func actionLabel(
    systemImage: String,
    title: String,
    foreground: Color
  ) -> some View {
    HStack(spacing: 6) {
      Image(systemName: systemImage)
        .font(AppTheme.symbol(size: 14, weight: .medium))
      Text(title)
        .pretendard(.body2)
    }
    .foregroundStyle(foreground)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding(.horizontal, 14)
  }
}

#Preview {
  UserProfileActionRow(
    isCreatingRoom: false,
    messageAction: {},
    storeAction: {}
  )
  .padding(20)
  .background(AppTheme.background)
  .preferredColorScheme(.dark)
}
