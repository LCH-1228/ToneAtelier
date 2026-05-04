//
//  HomeRemoteImageView.swift
//  ToneAtelier
//
//  Created by Codex on 4/24/26.
//

import ComposableArchitecture
import SwiftUI
import UIKit

struct HomeRemoteImageView: View {
  @Dependency(\.imageClient) private var imageClient

  let urlString: String?
  var contentMode: ContentMode = .fill
  var placeholderIconName: String?

  @State private var image: UIImage?
  @State private var hasFailed = false

  var body: some View {
    Group {
      if let image {
        Image(uiImage: image)
          .resizable()
          .aspectRatio(contentMode: contentMode)
          .transition(.opacity)
      } else {
        placeholder
          .transition(.opacity)
      }
    }
    .task(id: urlString) {
      guard let urlString, !urlString.trimmed.isEmpty else {
        withAnimation(.easeInOut(duration: 0.2)) {
          image = nil
          hasFailed = true
        }
        return
      }

      image = nil
      hasFailed = false

      do {
        let data = try await imageClient.fetchData(urlString)
        guard !Task.isCancelled else { return }

        withAnimation(.easeInOut(duration: 0.3)) {
          image = UIImage(data: data)
          hasFailed = image == nil
        }
      } catch {
        guard !Task.isCancelled else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
          image = nil
          hasFailed = true
        }
      }
    }
  }

  private var placeholder: some View {
    LinearGradient(
      colors: [
        AppTheme.deepTurquoise,
        AppTheme.blackTurquoise
      ],
      startPoint: .topLeading,
      endPoint: .bottomTrailing
    )
    .overlay {
      if let placeholderIconName, hasFailed {
        Image(placeholderIconName)
          .renderingMode(.template)
          .resizable()
          .scaledToFit()
          .frame(width: 28, height: 28)
          .foregroundStyle(AppTheme.gray45.opacity(0.9))
      } else if hasFailed {
        Image(systemName: "exclamationmark.triangle")
          .font(AppTheme.symbol(size: 18, weight: .semibold))
          .foregroundStyle(AppTheme.gray45.opacity(0.85))
      } else {
        ProgressView()
          .tint(AppTheme.gray45.opacity(0.8))
      }
    }
  }
}
