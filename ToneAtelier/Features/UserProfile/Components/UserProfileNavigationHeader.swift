import SwiftUI

struct UserProfileNavigationHeader: View {
  let backAction: () -> Void

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

      Text("PROFILE")
        .mulgyeol(.bodyNormal)
        .foregroundStyle(AppTheme.gray60)
        .accessibilityAddTraits(.isHeader)

      Spacer()

      Color.clear.frame(width: 48, height: 48)
    }
    .frame(height: 56)
    .padding(.horizontal, 4)
  }
}

#Preview {
  UserProfileNavigationHeader(backAction: {})
    .background(AppTheme.background)
    .preferredColorScheme(.dark)
}
