import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:runaway/core/helper/services/notification_service.dart';
import 'notification_event.dart';
import 'notification_state.dart';

class NotificationBloc extends Bloc<NotificationEvent, NotificationState> {
  final NotificationService _notificationService;
  
  NotificationBloc({NotificationService? notificationService})
      : _notificationService = notificationService ?? NotificationService.instance,
        super(const NotificationState()) {
    
    on<NotificationInitializeRequested>(_onInitializeRequested);
    on<NotificationToggleRequested>(_onToggleRequested);
  }
  
  Future<void> _onInitializeRequested(
    NotificationInitializeRequested event,
    Emitter<NotificationState> emit,
  ) async {
    if (state.isInitialized) return;
    
    emit(state.copyWith(isLoading: true));
    
    try {
      await _notificationService.initialize();
      
      emit(state.copyWith(
        isInitialized: true,
        notificationsEnabled: _notificationService.notificationsEnabled,
        fcmToken: _notificationService.fcmToken,
        isLoading: false,
        errorMessage: null,
      ));
      
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      ));
    }
  }
  
  Future<void> _onToggleRequested(
    NotificationToggleRequested event,
    Emitter<NotificationState> emit,
  ) async {
    emit(state.copyWith(isLoading: true));
    
    try {
      await _notificationService.toggleNotifications(event.enabled);
      
      emit(state.copyWith(
        notificationsEnabled: event.enabled,
        fcmToken: event.enabled ? _notificationService.fcmToken : null,
        isLoading: false,
        errorMessage: null,
      ));
      
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      ));
    }
  }
}