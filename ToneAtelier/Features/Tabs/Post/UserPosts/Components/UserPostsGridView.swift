//
//  UserPostsGridView.swift
//  ToneAtelier
//
//  Created by Codex on 5/3/26.
//
//  Pencil node: E0UwBc (u_grid)
//

import SwiftUI

struct UserPostsGridView: View {
  let posts: [PostSummaryResponseDTO]
  let isPaginating: Bool
  let onCardTap: (String) -> Void
  let onLastCardAppear: (String) -> Void

  var body: some View {
    LazyVStack(spacing: 12) {
      ForEach(posts, id: \.postID) { post in
        PostSmallCardView(
          post: post,
          baseURL: nil,
          action: { onCardTap(post.postID) }
        )
        .onAppear {
          if post.postID == posts.last?.postID {
            onLastCardAppear(post.postID)
          }
        }
      }

      if isPaginating {
        PostListPaginationLoaderView(isLoading: true)
          .padding(.vertical, 8)
      }
    }
  }
}
