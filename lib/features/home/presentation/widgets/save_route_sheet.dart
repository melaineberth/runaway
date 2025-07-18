import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:runaway/core/helper/extensions/extensions.dart';
import 'package:runaway/core/widgets/modal_sheet.dart';
import 'package:runaway/core/widgets/squircle_btn.dart';
import 'package:runaway/features/auth/presentation/widgets/auth_text_field.dart';

class SaveRouteSheet extends StatefulWidget {
  final String initialValue;
  const SaveRouteSheet({required this.initialValue, super.key});

  @override
  State<SaveRouteSheet> createState() => _SaveRouteSheetState();
}

class _SaveRouteSheetState extends State<SaveRouteSheet> {
  late final TextEditingController _ctl;

  @override
  void initState() {
    super.initState();
    _ctl = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    return ModalSheet(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.chooseName,
              style: context.bodySmall?.copyWith(
                color: context.adaptiveTextPrimary,
              ),
            ),
            2.h,
            Text(
              context.l10n.canModifyLater,
              style: context.bodySmall?.copyWith(
                color: context.adaptiveTextSecondary,
                fontSize: 15,
                fontWeight: FontWeight.w500
              ),
            ),
            20.h,
            AuthTextField(
              controller: _ctl,
              hint: context.l10n.routeName,
              maxLines: 1,
            ),
              
            12.h,

            SquircleBtn(
              isPrimary: true,
              onTap: () {
                final name = _ctl.text.trim();
                if (name.isEmpty) return;
                context.pop(name);
              }, // 🆕 Désactiver si loading
              label: context.l10n.save,
            ),              
          ],
        ),
      ),
    );
  }
}