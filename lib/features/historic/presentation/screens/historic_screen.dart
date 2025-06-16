import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:runaway/config/extensions.dart';
import 'package:runaway/core/widgets/ask_registration.dart';
import 'package:runaway/features/account/presentation/screens/account_screen.dart';
import 'package:runaway/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:runaway/features/auth/presentation/bloc/auth_state.dart';
import '../widgets/historic_card.dart';

class HistoricScreen extends StatelessWidget {  
  const HistoricScreen({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
  final List<HistoricCard> data = [];

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
                "Historique",
                style: context.bodySmall?.copyWith(
                  color: Colors.white,
                ),
              ),
            ),
            body: data.length > 1 ? BlurryPage(
              padding: EdgeInsets.all(20.0),
              children: List.generate(
                data.length, 
                (index) => Padding(
                  padding: EdgeInsets.only(bottom: index >= data.length ? 0 : 15.0),
                  child: data[index],
                ),
              ),
            ) : null,
          );
        }
        
        return SizedBox.shrink();
      }
    );
  }
}