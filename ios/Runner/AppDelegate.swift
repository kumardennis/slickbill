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

        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self
        application.registerForRemoteNotifications()

        guard let controller = window?.rootViewController as? FlutterViewController else {
            return super.application(application, didFinishLaunchingWithOptions: launchOptions)
        }
        
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
}