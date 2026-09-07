import UIKit
import Flutter
import UserNotifications
import FirebaseCore
import FirebaseMessaging

@main
@objc class AppDelegate: FlutterAppDelegate, MessagingDelegate {
    private let CHANNEL_PDF_BYTES = "com.example.slickbill/getPdfBytes"
    private let CHANNEL_EXTRACT_TEXT = "com.example.slickbill/extractText"
    private let CHANNEL_NFC = "com.example.slickbill/nfc"
    
    private var pendingFileURL: URL?
    
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {

        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }

        GeneratedPluginRegistrant.register(with: self)
        SbHaptics.register(with: self)
        SbHaptics.warm()

        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self
        application.registerForRemoteNotifications()

        guard let controller = window?.rootViewController as? FlutterViewController else {
            return super.application(application, didFinishLaunchingWithOptions: launchOptions)
        }
        SbHaptics.register(messenger: controller.binaryMessenger)
        
        // NFC Channel
        let nfcChannel = FlutterMethodChannel(name: CHANNEL_NFC,
                                            binaryMessenger: controller.binaryMessenger)
        nfcChannel.setMethodCallHandler({ [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
            if call.method == "getIntentAction" {
                // iOS doesn't have intents like Android, but we can check if app was opened with a file
                if let pendingURL = self?.pendingFileURL {
                    result("android.intent.action.VIEW") // Simulate Android intent
                } else {
                    result(nil)
                }
            } else {
                result(FlutterMethodNotImplemented)
            }
        })
        
        // PDF Bytes Channel
        let pdfBytesChannel = FlutterMethodChannel(name: CHANNEL_PDF_BYTES,
                                                 binaryMessenger: controller.binaryMessenger)
        pdfBytesChannel.setMethodCallHandler({ [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
            if let fileURL = self?.pendingFileURL {
                do {
                    let fileData = try Data(contentsOf: fileURL)
                    let flutterData = FlutterStandardTypedData(bytes: fileData)
                    result(flutterData)
                    
                    // Clear the pending file after processing
                    self?.pendingFileURL = nil
                } catch {
                    result(FlutterError(code: "FILE_READ_ERROR", 
                                      message: "Could not read file data", 
                                      details: error.localizedDescription))
                }
            } else {
                result(FlutterError(code: "NO_FILE_DATA", 
                                  message: "No file data found", 
                                  details: nil))
            }
        })
        
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    override func application(_ application: UIApplication,
                              didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
        super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
    }

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("FCM registration token refreshed: \(fcmToken ?? "nil")")
    }
    
    // Handle file opening from other apps
    override func application(_ app: UIApplication, 
                            open url: URL, 
                            options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        
        // Store the file URL for later retrieval
        if url.isFileURL {
            pendingFileURL = url
        }
        
        return super.application(app, open: url, options: options)
    }
    
    // Handle document interaction (iOS 9+)
    override func application(_ application: UIApplication, 
                            continue userActivity: NSUserActivity, 
                            restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        
        if userActivity.activityType == NSUserActivityTypeBrowsingWeb,
           let url = userActivity.webpageURL {
            pendingFileURL = url
        }
        
        return super.application(application, continue: userActivity, restorationHandler: restorationHandler)
    }

    override func applicationDidBecomeActive(_ application: UIApplication) {
        SbHaptics.warm()
        super.applicationDidBecomeActive(application)
    }
}

/// Retained UIKit generators. Flutter's HapticFeedback often never fires on
/// iOS 17.5+ because it builds a generator and returns without impactOccurred.
enum SbHaptics {
    private static let channelName = "slickbill/haptics"
    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let medium = UIImpactFeedbackGenerator(style: .medium)
    private static let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private static let selection = UISelectionFeedbackGenerator()
    private static let notify = UINotificationFeedbackGenerator()

    static var registered = false

    static func register(with registrarHost: FlutterPluginRegistry) {
        guard !registered, let registrar = registrarHost.registrar(forPlugin: "SbHaptics") else {
            return
        }
        register(messenger: registrar.messenger())
    }

    static func register(messenger: FlutterBinaryMessenger) {
        guard !registered else { return }
        registered = true
        let channel = FlutterMethodChannel(
            name: channelName,
            binaryMessenger: messenger
        )
        channel.setMethodCallHandler { call, result in
            switch call.method {
            case "warm":
                warm()
                result(nil)
            case "play":
                play(call.arguments as? String ?? "medium")
                result(nil)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    static func warm() {
        if #available(iOS 17.5, *), let view = keyView() {
            UIImpactFeedbackGenerator(style: .light, view: view).prepare()
            UIImpactFeedbackGenerator(style: .medium, view: view).prepare()
            UIImpactFeedbackGenerator(style: .heavy, view: view).prepare()
            UISelectionFeedbackGenerator(view: view).prepare()
            UINotificationFeedbackGenerator(view: view).prepare()
        }
        light.prepare()
        medium.prepare()
        heavy.prepare()
        selection.prepare()
        notify.prepare()
    }

    static func play(_ kind: String) {
        if #available(iOS 17.5, *), let view = keyView() {
            switch kind {
            case "selection":
                let generator = UISelectionFeedbackGenerator(view: view)
                generator.prepare()
                generator.selectionChanged()
            case "light":
                let generator = UIImpactFeedbackGenerator(style: .light, view: view)
                generator.prepare()
                generator.impactOccurred()
            case "heavy", "error":
                if kind == "error" {
                    let generator = UINotificationFeedbackGenerator(view: view)
                    generator.prepare()
                    generator.notificationOccurred(.error)
                } else {
                    let generator = UIImpactFeedbackGenerator(style: .heavy, view: view)
                    generator.prepare()
                    generator.impactOccurred()
                }
            default:
                let generator = UIImpactFeedbackGenerator(style: .medium, view: view)
                generator.prepare()
                generator.impactOccurred()
            }
            return
        }

        switch kind {
        case "selection":
            selection.selectionChanged()
            selection.prepare()
        case "light":
            light.impactOccurred()
            light.prepare()
        case "heavy":
            heavy.impactOccurred()
            heavy.prepare()
        case "error":
            notify.notificationOccurred(.error)
            notify.prepare()
        default:
            medium.impactOccurred()
            medium.prepare()
        }
    }

    private static func keyView() -> UIView? {
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
        if let view = windows.first(where: { $0.isKeyWindow })?.rootViewController?.view {
            return view
        }
        return windows.first?.rootViewController?.view
    }
}