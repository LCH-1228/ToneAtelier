//
//  HomeDetailAuthorSection.swift
//  ToneAtelier
//
//  Created by Codex on 4/27/26.
//

import SwiftUI

struct HomeDetailAuthorSection: View {
  let name: String
  let subtitle: String
  let profileImageURL: String?

  var body: some View {
    // TODO: profileAction, messageAction 진입 연결
    UserProfileHeader(
      name: name,
      subtitle: subtitle,
      profileImageURL: profileImageURL,
      profileAction: {},
      messageAction: {}
    )
  }
}
