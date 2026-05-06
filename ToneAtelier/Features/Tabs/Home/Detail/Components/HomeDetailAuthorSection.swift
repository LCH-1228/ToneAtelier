//
//  HomeDetailAuthorSection.swift
//  ToneAtelier
//
//  Created by Codex on 4/27/26.
//

import SwiftUI

struct HomeDetailAuthorSection: View {
  let authorUserID: String
  let name: String
  let subtitle: String
  let profileImageURL: String?
  let currentUserID: String?
  let profileAction: () -> Void
  let messageAction: () -> Void

  private var isSelf: Bool {
    guard let currentUserID, !currentUserID.isEmpty else { return false }
    return authorUserID == currentUserID
  }

  var body: some View {
    UserProfileHeader(
      name: name,
      subtitle: subtitle,
      profileImageURL: profileImageURL,
      isSelf: isSelf,
      profileAction: profileAction,
      messageAction: messageAction
    )
  }
}
