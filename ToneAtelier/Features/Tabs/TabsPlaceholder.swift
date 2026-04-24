//
//  TabsPlaceholder.swift
//  ToneAtelier
//
//  Created by Codex on 4/23/26.
//

import SwiftUI

struct TabPlaceholderView: View {
  let title: String
  let subtitle: String
  let details: [String]
  let symbolName: String
  let accentColor: Color
  let logoutAction: () -> Void

  var body: some View {
    ZStack {
      LinearGradient(
        colors: [
          Color(red: 0.05, green: 0.06, blue: 0.08),
          accentColor.opacity(0.38)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
      .ignoresSafeArea()

      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          VStack(alignment: .leading, spacing: 12) {
            Image(systemName: symbolName)
              .font(.system(size: 36, weight: .semibold))
              .foregroundStyle(.white)

            Text(title)
              .font(.largeTitle.bold())
              .foregroundStyle(.white)

            Text(subtitle)
              .font(.subheadline)
              .foregroundStyle(.white.opacity(0.68))
              .fixedSize(horizontal: false, vertical: true)
          }

          VStack(alignment: .leading, spacing: 12) {
            Text("다음 구현 예정")
              .font(.headline.weight(.semibold))
              .foregroundStyle(.white)

            ForEach(details, id: \.self) { detail in
              HStack(alignment: .top, spacing: 10) {
                Circle()
                  .fill(.white.opacity(0.82))
                  .frame(width: 6, height: 6)
                  .padding(.top, 8)

                Text(detail)
                  .font(.body)
                  .foregroundStyle(.white.opacity(0.84))
              }
            }
          }
          .padding(18)
          .background(.white.opacity(0.08))
          .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
          .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
              .stroke(.white.opacity(0.08), lineWidth: 1)
          }

          Text("인증 루트 전환과 탭 구조만 먼저 고정한 상태입니다.")
            .font(.footnote)
            .foregroundStyle(.white.opacity(0.44))
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 8)
        }
        .padding(.horizontal, 16)
        .padding(.top, 24)
        .padding(.bottom, 32)
      }
    }
    .navigationTitle(title)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button("로그아웃", action: logoutAction)
          .tint(.white)
      }
    }
  }
}

#Preview {
  NavigationStack {
    TabPlaceholderView(
      title: "홈",
      subtitle: "메인 탭 플레이스홀더입니다.",
      details: ["배너", "추천", "상세 진입"],
      symbolName: "house.fill",
      accentColor: .orange
    ) {}
  }
}
