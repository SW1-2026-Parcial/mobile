import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    
    GeneratedPluginRegistrant.register(with: self)
    
    // Configurar el delegado para interceptar notificaciones
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    }
      
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // MÉTRICA CRÍTICA: Este método permite el banner en Foreground
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    // Aquí obligamos a iOS a mostrar alerta y sonido aunque la app esté abierta
    if #available(iOS 14.0, *) {
        completionHandler([[.banner, .sound, .badge]])
    } else {
        completionHandler([[.alert, .sound, .badge]])
    }
  }
}
