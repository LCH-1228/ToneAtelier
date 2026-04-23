//
//  APIRouterDebugMenuView.swift
//  ToneAtelier
//
//  Created by Codex on 4/23/26.
//

import SwiftUI

struct APIRouterDebugMenuView: View {
  var body: some View {
    List {
      Section("Router Tests") {
        NavigationLink {
          AuthRouterTestView()
        } label: {
          APITestMenuRow(title: "Auth", subtitle: "refresh 토큰 갱신")
        }

        NavigationLink {
          UserRouterTestView()
        } label: {
          APITestMenuRow(title: "User", subtitle: "로그인, 프로필, 검색, 프로필 이미지 업로드")
        }

        NavigationLink {
          PostRouterTestView()
        } label: {
          APITestMenuRow(title: "Post", subtitle: "파일 업로드, 게시글 CRUD, 좋아요, 댓글")
        }

        NavigationLink {
          FilterRouterTestView()
        } label: {
          APITestMenuRow(title: "Filter", subtitle: "파일 업로드, 필터 CRUD, 좋아요, 댓글")
        }

        NavigationLink {
          ChatRouterTestView()
        } label: {
          APITestMenuRow(title: "Chat", subtitle: "채팅방, 메시지, 파일 업로드, 소켓 URL")
        }

        NavigationLink {
          CommerceRouterTestView()
        } label: {
          APITestMenuRow(title: "Commerce", subtitle: "주문 생성, 결제 검증, 영수증 조회")
        }

        NavigationLink {
          BannerRouterTestView()
        } label: {
          APITestMenuRow(title: "Banner", subtitle: "메인 배너 조회")
        }

        NavigationLink {
          NotificationRouterTestView()
        } label: {
          APITestMenuRow(title: "Notification", subtitle: "푸시 테스트 전송")
        }

        NavigationLink {
          VideoRouterTestView()
        } label: {
          APITestMenuRow(title: "Video", subtitle: "비디오 목록, 스트림, 좋아요")
        }

        NavigationLink {
          CommonRouterTestView()
        } label: {
          APITestMenuRow(title: "Common", subtitle: "서버 요청 로그 조회")
        }
      }

      Section("Notes") {
        Text("업로드 테스트는 앱 안에 포함된 1x1 PNG 샘플 파일을 사용합니다.")
        Text("업로드 응답으로 받은 파일 경로는 일부 화면에서 자동으로 입력 필드에 반영됩니다.")
      }
      .font(.caption)
      .foregroundStyle(.secondary)
    }
    .listStyle(.insetGrouped)
    .navigationTitle("API Router Tester")
  }
}

#Preview {
  NavigationStack {
    APIRouterDebugMenuView()
  }
}
