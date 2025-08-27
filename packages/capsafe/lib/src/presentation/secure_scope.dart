import 'package:flutter/widgets.dart';
import '../../capsafe.dart';

class SecureScope extends StatefulWidget {
  final ProtectionPolicy policy;
  final Widget child;
  final bool showUxMessageOnce;

  const SecureScope({
    super.key,
    required this.policy,
    required this.child,
    this.showUxMessageOnce = true,
  });

  @override
  State<SecureScope> createState() => _SecureScopeState();
}

class _SecureScopeState extends State<SecureScope> {
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    Capsafe.instance.useCases.enableProtection(widget.policy);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.showUxMessageOnce && !_shown) {
      _shown = true;
      Capsafe.instance.useCases.showUxMessage(context);
    }
  }

  @override
  void dispose() {
    Capsafe.instance.useCases.disableProtection();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
