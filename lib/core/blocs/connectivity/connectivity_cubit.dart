import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../helper/services/connectivity_service.dart';

class ConnectivityCubit extends Cubit<ConnectionStatus> {
  ConnectivityCubit(this._service) : super(_service.current) {
    _sub = _service.stream.listen(emit);
  }

  final ConnectivityService _service;
  late final StreamSubscription _sub;

  @override
  Future<void> close() {
    _sub.cancel();
    return super.close();
  }
}
