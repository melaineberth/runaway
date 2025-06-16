import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:runaway/config/extensions.dart';
import 'package:runaway/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:runaway/features/auth/presentation/bloc/auth_state.dart';

import '../../../../core/widgets/ask_registration.dart';

class ActivityScreen extends StatelessWidget {  
  const ActivityScreen({
    super.key,
  });

  @override
  Widget build(BuildContext context) {    
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (_, authState) {
        if (authState is Unauthenticated) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            showModalBottomSheet(
              context: context, 
              useRootNavigator: true,
              enableDrag: false,
              isDismissible: false,
              isScrollControlled: true,
              builder: (modalCtx) {
                return AskRegistration();
              },
            );
          });
        } 
        
        if (authState is Authenticated) {
          return Scaffold(
            extendBodyBehindAppBar: true,
            appBar: AppBar(
              forceMaterialTransparency: true,
              backgroundColor: Colors.transparent,
              title: Text(
                "Activité",
                style: context.bodySmall?.copyWith(
                  color: Colors.white,
                ),
              ),
            ),
          );
        }

        return SizedBox.shrink();
      }
    );
  }
}