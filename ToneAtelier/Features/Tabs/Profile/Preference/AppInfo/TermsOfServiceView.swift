//
//  TermsOfServiceView.swift
//  ToneAtelier
//
//  Created by Claude on 5/7/26.
//

import ComposableArchitecture
import SwiftUI

struct TermsOfServiceView: View {
  let store: StoreOf<TermsOfServiceFeature>

  var body: some View {
    ScrollView {
      Text(Self.attributed)
        .pretendard(.captionParagraph)
        .foregroundStyle(AppTheme.gray60)
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 32)
    }
    .scrollIndicators(.hidden)
    .background(AppTheme.background.ignoresSafeArea())
    .navigationBarTitleDisplayMode(.inline)
    .toolbarBackground(AppTheme.background, for: .navigationBar)
    .toolbarColorScheme(.dark, for: .navigationBar)
    .toolbar {
      PrincipalToolbarTitle("TERMS")
    }
  }

  private static let attributed: AttributedString = {
    guard let url = Bundle.main.url(forResource: "TermsOfService", withExtension: "md"),
          let raw = try? String(contentsOf: url, encoding: .utf8) else {
      return AttributedString("이용 약관을 불러오지 못했어요.")
    }
    let options = AttributedString.MarkdownParsingOptions(
      interpretedSyntax: .inlineOnlyPreservingWhitespace
    )
    return (try? AttributedString(markdown: raw, options: options))
      ?? AttributedString(raw)
  }()
}

#Preview {
  NavigationStack {
    TermsOfServiceView(
      store: Store(initialState: TermsOfServiceFeature.State()) {
        TermsOfServiceFeature()
      }
    )
  }
  .preferredColorScheme(.dark)
}
