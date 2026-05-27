//
//  ChatImageView.swift
//  ToneAtelier
//
//  Created by LCH on 4/29/26.
//

import ComposableArchitecture
import SwiftUI
import UIKit

/// 인증 헤더가 필요한 서버 이미지를 자동 다운로드해 표시하는 SwiftUI View.
///
/// 핵심 동작
/// - `imageClient.fetchData` → 내부적으로 `commonClient.fetchPhoto` → `httpClient.send`
///   를 거치므로 SeSACKey/Bearer 헤더와 토큰 갱신 흐름을 그대로 따른다.
/// - `LiveImageStore`(메모리)와 `LiveImageDiskStore`(영구 디스크)가 캐시·저장을 담당한다.
/// - 다운로드 중에는 도넛(circular ProgressView)을 placeholder 위에 overlay 한다.
/// - 실패 시 plain placeholder. 사용자 지시상 풀스크린 뷰어/탭 제스처는 두지 않는다.
///
/// 호출부는 서버가 내려준 raw path(예: `/v1/data/profiles/abc.png` 또는 `data/...`)를 그대로 전달한다.
/// `CommonRouter.fetchPhoto`가 `APIInfo.Path.photo` prefix와 leading slash 정규화를 담당.
struct ChatImageView: View {
  /// 서버가 내려준 path. 절대 URL이 들어오면 그대로 사용한다.
  let path: String?
  /// baseURL은 절대 URL 케이스에서 fallback으로 사용한다. 일반 path 케이스에서는 사용되지 않는다.
  /// 호환성을 위해 주입받지만 내부 fetchPhoto 흐름은 baseURL을 직접 참조하지 않는다.
  let baseURL: URL?
  /// 이미지를 클립할 도형. 기본은 cornerRadius 0(직사각형).
  let shape: ChatImageShape
  /// 이미지가 비어있을 때(또는 실패) 표시할 placeholder 종류.
  let placeholder: ChatImagePlaceholder
  /// 이미지를 frame에 맞추는 방식. 카드/썸네일은 `.fill`(default), 풀스크린 viewer는 `.fit` 권장.
  let contentMode: ContentMode

  init(
    path: String?,
    baseURL: URL?,
    shape: ChatImageShape = .roundedRect(cornerRadius: 0),
    placeholder: ChatImagePlaceholder = .photo,
    contentMode: ContentMode = .fill
  ) {
    self.path = path
    self.baseURL = baseURL
    self.shape = shape
    self.placeholder = placeholder
    self.contentMode = contentMode
  }

  @Dependency(\.imageClient) private var imageClient

  @State private var image: UIImage?
  @State private var isLoading = false
  @State private var hasFailed = false

  var body: some View {
    // `frame(maxWidth/maxHeight: .infinity)`로 부모가 지정한 frame을 가득 채운다.
    // `Image.scaledToFill`이 자기 본연 크기로 확장하는 것을 막기 위해 `.clipped()`를 적용해
    // 외부 frame을 절대 넘지 않도록 한다. 이후 `clipShape`이 외곽 모서리를 다듬는다.
    contentLayer
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .clipped()
      .clipShape(shape.shape)
      .task(id: pathKey) {
        await load()
      }
  }

  // MARK: - Layers

  @ViewBuilder
  private var contentLayer: some View {
    if let image {
      Image(uiImage: image)
        .resizable()
        .aspectRatio(contentMode: contentMode)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    } else if isLoading {
      ZStack {
        placeholderLayer
        ProgressView()
          .progressViewStyle(.circular)
          .tint(AppTheme.gray45)
      }
    } else if hasFailed {
      ZStack {
        placeholderLayer
        Image(systemName: "exclamationmark.triangle")
          .foregroundStyle(AppTheme.gray60)
      }
    } else {
      placeholderLayer
    }
  }

  @ViewBuilder
  private var placeholderLayer: some View {
    switch placeholder {
    case .photo:
      ZStack {
        AppTheme.blackTurquoise
        Image(systemName: "photo")
          .foregroundStyle(AppTheme.gray60)
      }
    case .person:
      ZStack {
        AppTheme.deepTurquoise
        Image(systemName: "person.fill")
          .foregroundStyle(AppTheme.gray60)
      }
    }
  }

  // MARK: - Loading

  /// `task(id:)`에 사용할 키. 외부에서 absolute URL이 들어와도 동일 path로 dedup.
  private var pathKey: String { path ?? "" }

  private func load() async {
    guard let path, !path.isEmpty else {
      image = nil
      isLoading = false
      hasFailed = false
      return
    }

    // 절대 URL이 직접 들어온 경우(scheme 보유)는 fetchPhoto의 path 처리와 호환되지 않으므로
    // 서버가 내려준 raw path를 그대로 사용한다. URL(string:)로 scheme 검사만 하여 분기.
    if let direct = URL(string: path), direct.scheme != nil {
      // 절대 URL 케이스: 인증이 필요 없는 외부 이미지로 간주하고 URLSession.shared로 직접 fetch.
      await loadDirectURL(direct)
      return
    }

    if let cached = await ChatImageDecodedCache.shared.image(for: path) {
      image = cached
      isLoading = false
      hasFailed = false
      return
    }

    image = nil
    isLoading = true
    hasFailed = false

    do {
      let data = try await imageClient.fetchData(path)
      try Task.checkCancellation()
      if let decoded = UIImage(data: data) {
        await ChatImageDecodedCache.shared.set(decoded, for: path)
        image = decoded
      } else {
        hasFailed = true
      }
    } catch is CancellationError {
      // 화면 사라짐/path 교체로 인한 취소는 조용히 무시.
    } catch {
      hasFailed = true
    }

    isLoading = false
  }

  private func loadDirectURL(_ url: URL) async {
    let key = url.absoluteString
    if let cached = await ChatImageDecodedCache.shared.image(for: key) {
      image = cached
      isLoading = false
      hasFailed = false
      return
    }

    image = nil
    isLoading = true
    hasFailed = false

    do {
      let (data, response) = try await URLSession.shared.data(from: url)
      try Task.checkCancellation()
      if
        let http = response as? HTTPURLResponse,
        (200..<300).contains(http.statusCode),
        let decoded = UIImage(data: data) {
        await ChatImageDecodedCache.shared.set(decoded, for: key)
        image = decoded
      } else {
        hasFailed = true
      }
    } catch is CancellationError {
      // 무시
    } catch {
      hasFailed = true
    }

    isLoading = false
  }
}
