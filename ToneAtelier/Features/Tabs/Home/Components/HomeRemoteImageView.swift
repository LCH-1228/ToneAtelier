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
  @Dependency(\.commonClient) private var commonClient

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
      } else {
        placeholder
      }
    }
    .task(id: urlString) {
      guard let urlString, !urlString.trimmed.isEmpty else {
        image = nil
        hasFailed = true
        return
      }

      image = nil
      hasFailed = false

      do {
        let data = try await commonClient.fetchPhoto(urlString)
        guard !Task.isCancelled else { return }

        await MainActor.run {
          image = UIImage(data: data)
          hasFailed = image == nil
        }
      } catch {
        guard !Task.isCancelled else { return }
        await MainActor.run {
          image = nil
          hasFailed = true
        }
      }
    }
  }

  private var placeholder: some View {
    LinearGradient(
      colors: [
        HomeTheme.deepTurquoise,
        HomeTheme.blackTurquoise,
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
          .foregroundStyle(HomeTheme.gray45.opacity(0.9))
      } else if hasFailed {
        Image(systemName: "exclamationmark.triangle")
          .font(.system(size: 18, weight: .semibold))
          .foregroundStyle(HomeTheme.gray45.opacity(0.85))
      } else {
        ProgressView()
          .tint(HomeTheme.gray45.opacity(0.8))
      }
    }
  }
}
