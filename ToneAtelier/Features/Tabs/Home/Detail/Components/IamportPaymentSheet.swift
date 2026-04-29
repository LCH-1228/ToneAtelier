//
//  IamportPaymentSheet.swift
//  ToneAtelier
//
//  Created by LCH on 4/29/26.
//

import SwiftUI
import UIKit
import iamport_ios

// MARK: - 결제 요청 / 결과 모델

struct IamportPaymentRequest: Equatable, Sendable, Identifiable {
  // fullScreenCover(item:) 식별용. merchantUID는 주문당 1개로 고유.
  var id: String { merchantUID }

  /// 서버에서 받은 주문 코드 (CommerceClient.createOrder → OrderCreatedResponse.order_code)
  let merchantUID: String
  /// 결제 금액 (원 단위)
  let amount: Int
  /// 결제창에 표기될 상품명 (필터 이름)
  let name: String
  /// 외부 앱 호출 후 복귀용 URL Scheme. Info.plist `CFBundleURLSchemes`에 등록되어 있어야 한다.
  let appScheme: String
}

struct IamportPaymentResult: Equatable, Sendable {
  let merchantUID: String
  let impUID: String?
  let success: Bool
  let errorMessage: String?
}

// MARK: - 결제 기본 설정 (PG / 결제 수단)

private enum PaymentDefaults {
  /// PG사 식별자. 가맹점 환경에 따라 추후 교체.
  static let pg: PG = .html5_inicis
  /// PG 가맹점 식별 ID. 테스트 가맹점 기준 placeholder.
  static let pgId: String = "INIpayTest"
  /// 결제 수단. 카드 고정.
  static let payMethod: PayMethod = .card
  /// Info.plist에서 IamportUserCode를 읽을 키.
  static let userCodeInfoKey = "IamportUserCode"
}

// MARK: - SwiftUI 결제 시트

/// 아임포트 SDK 결제창을 SwiftUI에서 띄우기 위한 UIViewControllerRepresentable.
/// fullScreenCover로 표시한 뒤 viewDidAppear 시점에 1회만 결제창을 호출하고,
/// SDK 콜백 결과를 onComplete로 전달해 호출 측이 dismiss/처리할 수 있게 한다.
struct IamportPaymentSheet: UIViewControllerRepresentable {
  let request: IamportPaymentRequest
  let onComplete: (IamportPaymentResult) -> Void

  func makeCoordinator() -> Coordinator {
    Coordinator(request: request, onComplete: onComplete)
  }

  func makeUIViewController(context: Context) -> UIViewController {
    let controller = PaymentHostingController()
    controller.view.backgroundColor = .black
    controller.coordinator = context.coordinator
    return controller
  }

  func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
    // 결제 요청 트리거는 viewDidAppear 1회로 한정. 추가 동작 없음.
  }
}

// MARK: - Coordinator

extension IamportPaymentSheet {
  final class Coordinator {
    private let request: IamportPaymentRequest
    private let onComplete: (IamportPaymentResult) -> Void
    /// 결제창이 이미 한 번 호출되었는지. viewDidAppear가 여러 번 불려도 중복 호출을 막는다.
    private var didStartPayment = false

    init(
      request: IamportPaymentRequest,
      onComplete: @escaping (IamportPaymentResult) -> Void
    ) {
      self.request = request
      self.onComplete = onComplete
    }

    /// 결제창 1회 호출 진입점.
    func startPaymentIfNeeded(on viewController: UIViewController) {
      guard !didStartPayment else { return }
      didStartPayment = true

      let userCode = Bundle.main.object(forInfoDictionaryKey: PaymentDefaults.userCodeInfoKey) as? String ?? ""

      // xcconfig에 IamportUserCode가 비어있거나 치환되지 않은 채 들어오면 SDK가 사일런트로 실패한다.
      // 사용자에게 즉시 실패 콜백을 돌려 alert 흐름이 발동되게 한다.
      guard !userCode.isEmpty, !userCode.hasPrefix("$(") else {
        #if DEBUG
        assertionFailure("IamportUserCode missing in Info.plist / Secrets.xcconfig")
        #endif
        let result = IamportPaymentResult(
          merchantUID: request.merchantUID,
          impUID: nil,
          success: false,
          errorMessage: "결제 설정이 누락되었습니다. 관리자에게 문의해 주세요."
        )
        DispatchQueue.main.async { [onComplete] in
          onComplete(result)
        }
        return
      }

      let payment = IamportPayment(
        pg: PaymentDefaults.pg.makePgRawName(pgId: PaymentDefaults.pgId),
        merchant_uid: request.merchantUID,
        amount: String(request.amount)
      )
      payment.pay_method = PaymentDefaults.payMethod.rawValue
      payment.name = request.name
      payment.app_scheme = request.appScheme

      let merchantUID = request.merchantUID

      // SDK 콜백은 메인 스레드에서 호출됨이 보장되지 않을 수 있어 메인으로 보정.
      // self는 Coordinator. UIViewControllerRepresentable이 사라지면 Coordinator도 함께 해제되므로
      // weak self로 캡처해 잔여 콜백이 살아 있는 SwiftUI 트리를 강하게 잡지 않도록 한다.
      Iamport.shared.payment(
        viewController: viewController,
        userCode: userCode,
        payment: payment
      ) { [weak self] response in
        guard let self else { return }
        let result = Self.makeResult(merchantUID: merchantUID, response: response)
        DispatchQueue.main.async {
          self.onComplete(result)
        }
      }
    }

    /// IamportResponse → 도메인 모델 매핑.
    private static func makeResult(
      merchantUID: String,
      response: IamportResponse?
    ) -> IamportPaymentResult {
      let success = response?.success ?? false
      let impUID = response?.imp_uid
      let errorMessage = response?.error_msg
      return IamportPaymentResult(
        merchantUID: response?.merchant_uid ?? merchantUID,
        impUID: impUID,
        success: success,
        errorMessage: errorMessage
      )
    }

    deinit {
      print("Deinit: \(Self.self)")
    }
  }
}

// MARK: - PaymentHostingController

/// viewDidAppear 시점에 결제창을 1회만 트리거하는 호스트 ViewController.
private final class PaymentHostingController: UIViewController {
  weak var coordinator: IamportPaymentSheet.Coordinator?

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    coordinator?.startPaymentIfNeeded(on: self)
  }

  deinit {
    print("Deinit: \(Self.self)")
  }
}
