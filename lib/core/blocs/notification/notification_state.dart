import 'package:equatable/equatable.dart';

class NotificationState extends Equatable {
  final bool isInitialized;
  final bool notificationsEnabled;
  final bool isLoading;
  final String? errorMessage;
  final String? fcmToken;
  
  const NotificationState({
    this.isInitialized = false,
    this.notificationsEnabled = true,
    this.isLoading = false,
    this.errorMessage,
    this.fcmToken,
  });
  
  NotificationState copyWith({
    bool? isInitialized,
    bool? notificationsEnabled,
    bool? isLoading,
    String? errorMessage,
    String? fcmToken,
  }) {
    return NotificationState(
      isInitialized: isInitialized ?? this.isInitialized,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
      fcmToken: fcmToken ?? this.fcmToken,
    );
  }
  
  @override
  List<Object?> get props => [
    isInitialized,
    notificationsEnabled,
    isLoading,
    errorMessage,
    fcmToken,
  ];
}
