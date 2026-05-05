import SwiftUI

struct ChatRoomNavigationHeader: View {
  let title: String
  let backAction: () -> Void
  let deleteAction: () -> Void

  var body: some View {
    HStack {
      Button(action: backAction) {
        Image(systemName: "chevron.left")
          .font(AppTheme.symbol(size: 22, weight: .medium))
          .foregroundStyle(AppTheme.gray75)
          .frame(width: 48, height: 48)
          .contentShape(.rect)
      }
      .buttonStyle(.plain)
      .accessibilityLabel("뒤로 가기")

      Spacer()

      Text(title)
        .mulgyeol(.bodyNormal)
        .foregroundStyle(AppTheme.gray30)
        .accessibilityAddTraits(.isHeader)

      Spacer()

      Menu {
        Button(role: .destructive, action: deleteAction) {
          Label("채팅방 삭제", systemImage: "trash")
        }
      } label: {
        Image(systemName: "ellipsis")
          .font(AppTheme.symbol(size: 22, weight: .medium))
          .foregroundStyle(AppTheme.gray75)
          .frame(width: 48, height: 48)
          .contentShape(.rect)
      }
      .accessibilityLabel("더보기")
    }
    .frame(height: 56)
    .padding(.horizontal, 4)
  }
}

#Preview {
  ChatRoomNavigationHeader(title: "YOON", backAction: {}, deleteAction: {})
    .background(AppTheme.background)
    .preferredColorScheme(.dark)
}
