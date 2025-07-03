import 'package:equatable/equatable.dart';

abstract class NotificationEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class NotificationInitializeRequested extends NotificationEvent {}

class NotificationToggleRequested extends NotificationEvent {
  final bool enabled;
  
  NotificationToggleRequested({required this.enabled});
  
  @override
  List<Object?> get props => [enabled];
}