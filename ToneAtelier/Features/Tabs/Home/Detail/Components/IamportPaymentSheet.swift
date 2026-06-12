//
//  IamportPaymentSheet.swift
//  ToneAtelier
//
//  Created by LCH on 4/29/26.
//

import iamport_ios
import OSLog
import SwiftUI
import UIKit

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
  /// PG 영수증 페이지의 본인 확인 (이름/이메일/휴대폰 중 하나 매칭). 회원 정보 기준.
  let buyerName: String
  let buyerEmail: String
  let buyerTel: String
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
    // 결제 SDK가 모달을 띄우기 직전 노출되는 배경. 시스템 dynamic color(light=white, dark=black)로
    // 외관과 일치시켜 검정 배경 깜빡임을 줄인다.
    controller.view.backgroundColor = .systemBackground
    controller.coordinator = context.coordinator
    // SDK 의 navController 모드로 결제창을 push 하기 위해 host 를 UINavigationController 로 감싼다.
    // SDK 가 push 한 WebViewController 위에 우리 측 좌측 X 버튼을 부착해 모든 페이지에서 명시적 닫기 제공.
    let nav = UINavigationController(rootViewController: controller)
    nav.isNavigationBarHidden = false
    nav.delegate = controller
    // swipe-back gesture 비활성 — X 버튼만이 명시적 닫기 수단으로 동작하도록 한다.
    nav.interactivePopGestureRecognizer?.isEnabled = false
    return nav
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
    /// SDK 의 paymentResultCallback 이 한 번이라도 발화했는지.
    /// SDK 자체 Back 버튼은 callback 없이 dismiss만 호출하므로,
    /// 이 flag 가 false 인 채로 host VC 가 다시 visible 되면 cancel 로 처리한다.
    private var didReceiveResult = false

    init(
      request: IamportPaymentRequest,
      onComplete: @escaping (IamportPaymentResult) -> Void
    ) {
      self.request = request
      self.onComplete = onComplete
    }

    /// SDK WebViewController 가 callback 없이 dismiss 된 케이스 (KG이니시스 자체 X 버튼 등) 처리.
    /// PaymentHostingController.viewDidAppear 두 번째 호출 시점에 호출된다.
    func handleSDKDismissedWithoutResult() {
      cancelInternal()
    }

    /// 사용자가 우리 측 좌측 상단 X 버튼을 눌렀을 때 명시적 닫기.
    func requestCancel() {
      Iamport.shared.close()
      cancelInternal()
    }

    private func cancelInternal() {
      guard didStartPayment, !didReceiveResult else { return }
      didReceiveResult = true
      let result = IamportPaymentResult(
        merchantUID: request.merchantUID,
        impUID: nil,
        success: false,
        errorMessage: "결제가 취소되었습니다."
      )
      DispatchQueue.main.async { [onComplete] in
        onComplete(result)
      }
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
      payment.buyer_name = request.buyerName
      payment.buyer_email = request.buyerEmail
      payment.buyer_tel = request.buyerTel

      let merchantUID = request.merchantUID

      // SDK 콜백은 메인 스레드에서 호출됨이 보장되지 않을 수 있어 메인으로 보정.
      // self는 Coordinator. UIViewControllerRepresentable이 사라지면 Coordinator도 함께 해제되므로
      // weak self로 캡처해 잔여 콜백이 살아 있는 SwiftUI 트리를 강하게 잡지 않도록 한다.
      let completionHandler: (IamportResponse?) -> Void = { [weak self] response in
        guard let self else { return }
        guard !self.didReceiveResult else { return }
        self.didReceiveResult = true
        let result = Self.makeResult(merchantUID: merchantUID, response: response)
        DispatchQueue.main.async {
          self.onComplete(result)
        }
      }

      // navController 모드 우선 — SDK 가 WebViewController 를 push 해 iOS 표준 navigationBar /
      // swipe-back gesture 가 자동 활성화된다. host 가 UINavigationController 의 root 라 정상 흐름에선
      // 항상 navController 가 존재. 예외 케이스 방어용으로 viewController 모드 fallback 둠.
      if let navController = viewController.navigationController {
        Iamport.shared.payment(
          navController: navController,
          userCode: userCode,
          payment: payment,
          paymentResultCallback: completionHandler
        )
      } else {
        Iamport.shared.payment(
          viewController: viewController,
          userCode: userCode,
          payment: payment,
          paymentResultCallback: completionHandler
        )
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
      Logger.payment.debug("Deinit: \(String(describing: Self.self), privacy: .public)")
    }
  }
}

// MARK: - PaymentHostingController

/// viewDidAppear 시점에 결제창을 1회만 트리거하는 호스트 ViewController.
/// SDK 가 push 한 WebViewController 가 callback 없이 dismiss 되면 host 가 다시 active 되어
/// viewDidAppear 가 두 번째로 호출된다 — 이 시점에 cancel 로 처리해 검정화면 stuck 을 방지한다.
/// 또한 `UINavigationControllerDelegate` 로 push 된 wvc 에 좌측 X 버튼을 부착한다.
private final class PaymentHostingController: UIViewController, UINavigationControllerDelegate {
  weak var coordinator: IamportPaymentSheet.Coordinator?
  private var didStartPayment = false

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    if didStartPayment {
      coordinator?.handleSDKDismissedWithoutResult()
      return
    }
    didStartPayment = true
    coordinator?.startPaymentIfNeeded(on: self)
  }

  func navigationController(
    _ navigationController: UINavigationController,
    willShow viewController: UIViewController,
    animated: Bool
  ) {
    // host(self) 가 root 라 push 된 SDK WebViewController 에만 X 버튼 부착.
    guard viewController !== self else { return }
    let closeItem = UIBarButtonItem(
      image: UIImage(systemName: "xmark"),
      style: .plain,
      target: self,
      action: #selector(handleCloseButtonTapped)
    )
    viewController.navigationItem.leftBarButtonItem = closeItem
    // 시스템 기본 back 버튼 노출 방지 — X 만이 닫기 수단.
    viewController.navigationItem.hidesBackButton = true
  }

  @objc private func handleCloseButtonTapped() {
    coordinator?.requestCancel()
  }

  deinit {
    Logger.payment.debug("Deinit: \(String(describing: Self.self), privacy: .public)")
  }
}
