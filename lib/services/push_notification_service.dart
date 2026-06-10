import 'dart:async';
import 'dart:math';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // 백엔드 또는 FCM에서 전송된 백그라운드 메시지 처리 수신부
  await Firebase.initializeApp();
  if (kDebugMode) {
    print("Handling a background message: ${message.messageId}");
    print("Title: ${message.notification?.title}");
    print("Body: ${message.notification?.body}");
  }
}

class PushNotificationService {
  static final PushNotificationService instance = PushNotificationService._internal();

  PushNotificationService._internal();

  bool _isMockMode = false;
  String? _token;
  final StreamController<String> _tokenStreamController = StreamController<String>.broadcast();
  final StreamController<RemoteMessage> _messageStreamController = StreamController<RemoteMessage>.broadcast();

  bool get isMockMode => _isMockMode;
  String? get token => _token;
  Stream<String> get tokenStream => _tokenStreamController.stream;
  Stream<RemoteMessage> get messageStream => _messageStreamController.stream;

  Future<void> initialize() async {
    try {
      // 1. Firebase core 초기화 시도
      // (FCM 설정 파일이 없을 경우 예외 발생하므로 try-catch 감싸기)
      await Firebase.initializeApp();
      
      // 2. 백그라운드 메시지 핸들러 등록
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // 3. 알림 권한 요청 (iOS 및 Android 13+ 대응)
      final messaging = FirebaseMessaging.instance;
      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      if (kDebugMode) {
        print('User granted permission: ${settings.authorizationStatus}');
      }

      // 4. APNS 토큰 획득 대기 (iOS 기기 대응)
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await messaging.getAPNSToken();
      }

      // 5. FCM 토큰 획득
      _token = await messaging.getToken();
      if (_token != null) {
        _tokenStreamController.add(_token!);
        if (kDebugMode) {
          print("FCM Token: $_token");
        }
      }

      // 토큰 리프레시 리스너 설정
      messaging.onTokenRefresh.listen((newToken) {
        _token = newToken;
        _tokenStreamController.add(newToken);
        if (kDebugMode) {
          print("FCM Token Refreshed: $newToken");
        }
      });

      // 6. 포그라운드 수신 이벤트 리스너 설정
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        if (kDebugMode) {
          print('Got a message whilst in the foreground!');
          print('Message data: ${message.data}');
        }

        if (message.notification != null) {
          if (kDebugMode) {
            print('Message also contained a notification: ${message.notification}');
          }
        }
        _messageStreamController.add(message);
      });

      // 7. 알림 클릭으로 앱이 열렸을 때 리스너 설정
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        if (kDebugMode) {
          print('A new onMessageOpenedApp event was published!');
        }
        _messageStreamController.add(message);
      });

      _isMockMode = false;
      print("[PushNotificationService] FCM 연동 초기화 완료 (실제 기기/에뮬레이터 연결됨)");

    } catch (e) {
      // Firebase 설정 파일이 없거나 기기 연동에 실패했을 경우 Mock/Sandbox 모드 전환
      _isMockMode = true;
      final randomId = Random().nextInt(10000);
      _token = "MOCK_FCM_TOKEN_$randomId";
      _tokenStreamController.add(_token!);
      
      print("[PushNotificationService] Firebase 초기화 실패. Mock Sandbox 모드로 자동 전환됩니다.");
      print("[PushNotificationService] 원인: $e");
      print("[PushNotificationService] 임시 생성된 토큰: $_token");
    }
  }
}
