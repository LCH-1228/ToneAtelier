//
//  CommentDisplayItem.swift
//  ToneAtelier
//

import Foundation

/// 댓글/답글 행을 그릴 때 필요한 최소 표시 데이터.
/// Post/Filter 도메인의 DTO 가 도메인별로 분리되어 있어, 공통 row 컴포넌트가 받는 view-model 로 사용한다.
struct CommentDisplayItem: Identifiable, Equatable, Sendable {
  let commentID: String
  let content: String
  let createdAt: String
  let nick: String
  let profileImageURL: String?
  let creatorUserID: String
  let replies: [CommentDisplayItem]

  var id: String { commentID }
}
