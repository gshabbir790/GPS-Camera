import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/strings.dart';

/// بیک بٹن دبانے پر ایپ بند کرنے سے پہلے تصدیق
class ExitGuard extends StatelessWidget {
  final Widget child;
  const ExitGuard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(S.t('Exit app?', 'ایپ بند کریں؟')),
            content: Text(S.t('Do you want to close GPS Camera?',
                'کیا آپ GPS Camera بند کرنا چاہتے ہیں؟')),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(S.t('No', 'نہیں'))),
              FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(S.t('Yes, exit', 'ہاں، بند کریں'))),
            ],
          ),
        );
        if (ok == true) SystemNavigator.pop();
      },
      child: child,
    );
  }
}
