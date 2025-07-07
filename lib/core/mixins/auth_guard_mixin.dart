import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:runaway/config/constants.dart';
import 'package:runaway/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:runaway/features/auth/presentation/bloc/auth_state.dart';

mixin AuthGuardMixin<T extends StatefulWidget> on State<T> {
  bool _authChecked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_authChecked) return;

    final authState = context.read<AuthBloc>().state;
    if (authState is! Authenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) showAuthModal(context);
      });
    }
    _authChecked = true;
  }
}
