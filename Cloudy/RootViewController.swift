// Copyright (c) 2020 Nomad5. All rights reserved.

import UIKit
import WebKit

class FullScreenWKWebView: WKWebView {
    override var safeAreaInsets: UIEdgeInsets {
        .zero
    }
}

class RootViewController: UIViewController {

    /// Containers
    @IBOutlet var containerWebView: UIView!

    /// The hacked webView
    private var webView:   FullScreenWKWebView!
    private let navigator: Navigator = Navigator()

    var menu: MenuController? = nil

    /// By default hide the status bar
    override var prefersStatusBarHidden: Bool {
        true
    }

    /// The configuration used for the wk webView
    private lazy var webViewConfig: WKWebViewConfiguration = {
        let preferences = WKPreferences()
        preferences.javaScriptCanOpenWindowsAutomatically = true
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.applicationNameForUserAgent = "Version/13.0.1 Safari/605.1.15"
        config.userContentController.addScriptMessageHandler(WebViewControllerBridge(), contentWorld: WKContentWorld.page, name: "controller")
        config.preferences = preferences
        return config
    }()

    /// View will be shown shortly
    override func viewDidLoad() {
        super.viewDidLoad()
        // configure webView
        webView = FullScreenWKWebView(frame: view.bounds, configuration: webViewConfig)
        webView.translatesAutoresizingMaskIntoConstraints = false
        containerWebView.addSubview(webView)
        webView.fillParent()
        webView.uiDelegate = self
        webView.navigationDelegate = self
        // initial
        if let lastVisitedUrl = UserDefaults.standard.lastVisitedUrl {
            webView.navigateTo(url: lastVisitedUrl)
        } else {
            webView.navigateTo(url: Navigator.Config.Url.googleStadia)
        }
        // menu view controller
        let menuViewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "MenuViewController") as! MenuViewController
        menu = menuViewController
        menuViewController.hideMenu()
        menuViewController.webController = webView
        menuViewController.view.frame = view.bounds
        menuViewController.willMove(toParent: self)
        addChild(menuViewController)
        view.addSubview(menuViewController.view)
        menuViewController.didMove(toParent: self)
    }

    /// Tapped on the menu item
    @IBAction func onMenuButtonPressed(_ sender: Any) {
        menu?.show()
    }
}

/// WebView delegates
/// TODO extract this to a separate module with proper abstraction
extension RootViewController: WKNavigationDelegate, WKUIDelegate {

    /// When a stadia page finished loading, inject the controller override script
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // inject the script
        webView.injectControllerScript()
        // update address
        menu?.updateAddressBar(with: AddressBarInfo(url: webView.url?.absoluteString,
                                                    canGoBack: webView.canGoForward,
                                                    canGoForward: webView.canGoBack))
        // save last visited url
        UserDefaults.standard.lastVisitedUrl = webView.url
    }

    /// Handle popups
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil {
            let modalViewController = UIViewController()
            let modalWebView        = WKWebView(frame: view.bounds, configuration: configuration)
            modalViewController.view = modalWebView
            modalWebView.customUserAgent = Navigator.Config.UserAgent.chromeDesktop
            present(modalViewController, animated: true)
            modalWebView.load(navigationAction.request)
            return modalWebView
        }
        return nil
    }

    /// After successfully logging in, forward user to stadia
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        let navigation = navigator.getNavigation(for: navigationAction.request.url?.absoluteString)
        print("navigation -> \(navigationAction.request.url?.absoluteString ?? "nil") -> \(navigation)")
        webView.customUserAgent = navigation.userAgent
        if let forwardUrl = navigation.forwardToUrl {
            decisionHandler(.cancel)
            webView.navigateTo(url: forwardUrl)
            return
        }
        decisionHandler(.allow)
    }

}