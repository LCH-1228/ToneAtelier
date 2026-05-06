import SwiftUI

struct ChatDayDividerView: View {
  let date: Date

  var body: some View {
    Text(formatted)
      .pretendard(.captionMeta)
      .foregroundStyle(AppTheme.gray60)
      .padding(.horizontal, 12)
      .padding(.vertical, 4)
      .background(Capsule().fill(AppTheme.blackTurquoise.opacity(0.6)))
      .frame(maxWidth: .infinity)
      .padding(.vertical, 8)
  }

  private var formatted: String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.dateFormat = "yyyy년 M월 d일"
    return formatter.string(from: date)
  }
}

#Preview {
  ChatDayDividerView(date: Date())
    .background(AppTheme.background)
    .preferredColorScheme(.dark)
}
