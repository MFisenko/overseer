import 'package:flutter/material.dart';

import '../../models/appearance.dart';
import '../../models/companion.dart';
import '../../services/auth_service.dart';
import '../../theme/tokens.dart';
import '../../theme/type.dart';
import '../../widgets/companion/overseer_eye.dart';
import '../../widgets/primitives.dart';

/// The door.
///
/// Kept to one field pair and one button. Signing in is not the product, and
/// anything that makes it feel like a form is friction in front of the thing
/// the user actually came for.
class SignInScreen extends StatefulWidget {
  const SignInScreen({
    super.key,
    required this.auth,
    required this.onSkip,
  });

  final AuthService auth;

  /// Lets someone in without an account. The app is fully playable on local
  /// storage, and demanding registration before anyone has seen the thing is a
  /// good way to lose them.
  final VoidCallback onSkip;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _registering = false;
  bool _busy = false;
  String? _error;
  String? _notice;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Both fields, please.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });

    final err = _registering
        ? await widget.auth.register(email, password)
        : await widget.auth.signIn(email, password);

    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = err;
    });
    // On success the auth stream fires and the shell swaps itself out; there is
    // nothing to navigate to from here.
  }

  Future<void> _reset() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Enter your email first.');
      return;
    }
    final err = await widget.auth.sendReset(email);
    if (!mounted) return;
    setState(() {
      _error = err;
      _notice = err == null ? 'Reset link sent to $email.' : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Gap.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: OverseerEye(
                      mood: CompanionMood.watching,
                      appearance: const Appearance(),
                      size: 96,
                      flat: true,
                      lookAt: Offset.zero,
                    ),
                  ),
                  const SizedBox(height: Gap.xl),
                  Text('OVERSEER', style: Kind.label(context, size: 11)),
                  const SizedBox(height: Gap.sm),
                  Text(
                    _registering ? 'Open an account' : 'Identify yourself',
                    style: Kind.display(context, size: 32),
                  ),
                  const SizedBox(height: Gap.sm),
                  Text(
                    _registering
                        ? 'Your directives, manifest and progress follow the '
                            'account, not the device.'
                        : 'Everything picks up where you left it.',
                    style: Kind.body(context, size: 13),
                  ),

                  const SizedBox(height: Gap.xl),
                  TextField(
                    controller: _email,
                    autofillHints: const [AutofillHints.email],
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    style: Kind.body(context, size: 15, color: tk.ink),
                    cursorColor: tk.accent,
                    decoration: const InputDecoration(hintText: 'email'),
                  ),
                  const SizedBox(height: Gap.sm),
                  TextField(
                    controller: _password,
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    textInputAction: TextInputAction.done,
                    style: Kind.body(context, size: 15, color: tk.ink),
                    cursorColor: tk.accent,
                    decoration: const InputDecoration(hintText: 'password'),
                    onSubmitted: (_) => _submit(),
                  ),

                  if (_error != null) ...[
                    const SizedBox(height: Gap.md),
                    Text(_error!,
                        style: Kind.body(context, size: 12.5, color: tk.alert)),
                  ],
                  if (_notice != null) ...[
                    const SizedBox(height: Gap.md),
                    Text(_notice!,
                        style: Kind.body(context, size: 12.5, color: tk.cool)),
                  ],

                  const SizedBox(height: Gap.lg),
                  SoftButton(
                    label: _busy
                        ? 'WORKING'
                        : _registering
                            ? 'CREATE ACCOUNT'
                            : 'SIGN IN',
                    primary: true,
                    expand: true,
                    onTap: _busy ? null : _submit,
                  ),

                  const SizedBox(height: Gap.md),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() {
                            _registering = !_registering;
                            _error = null;
                            _notice = null;
                          }),
                          behavior: HitTestBehavior.opaque,
                          child: Text(
                            _registering
                                ? 'I already have an account'
                                : 'Create an account',
                            style: Kind.body(context, size: 12.5, color: tk.accent),
                          ),
                        ),
                      ),
                      if (!_registering)
                        GestureDetector(
                          onTap: _reset,
                          behavior: HitTestBehavior.opaque,
                          child: Text('Forgot password',
                              style: Kind.body(
                                  context, size: 12.5, color: tk.inkDim)),
                        ),
                    ],
                  ),

                  const SizedBox(height: Gap.xl),
                  Rule(),
                  const SizedBox(height: Gap.md),
                  SoftButton(
                    label: 'CONTINUE WITHOUT AN ACCOUNT',
                    expand: true,
                    dense: true,
                    onTap: widget.onSkip,
                  ),
                  const SizedBox(height: Gap.sm),
                  Text(
                    'Everything works offline on this device. Sign in later and '
                    'what you have done comes with you.',
                    style: Kind.body(context, size: 11.5, color: tk.inkDim),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
