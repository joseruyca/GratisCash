import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config.dart';
import '../../core/services.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _displayName = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirmPassword = TextEditingController();

  bool _register = false;
  bool _acceptedTerms = false;
  bool _adultConfirmed = false;
  bool _showPassword = false;
  bool _showConfirmPassword = false;
  bool _busy = false;

  @override
  void dispose() {
    _displayName.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  String? _emailValidator(String? value) {
    final text = value?.trim() ?? '';
    final valid = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(text);
    if (!valid) {
      return 'Introduce un email válido';
    }
    return null;
  }

  String? _displayNameValidator(String? value) {
    if (!_register) {
      return null;
    }
    final text = value?.trim() ?? '';
    if (text.length < 2 || text.length > 60) {
      return 'Usa entre 2 y 60 caracteres';
    }
    return null;
  }

  String? _passwordValidator(String? value) {
    final text = value ?? '';
    if (_register) {
      if (text.length < 12) {
        return 'Usa al menos 12 caracteres';
      }
      if (!RegExp(r'[a-z]').hasMatch(text) ||
          !RegExp(r'[A-Z]').hasMatch(text) ||
          !RegExp(r'[0-9]').hasMatch(text)) {
        return 'Incluye mayúsculas, minúsculas y números';
      }
    } else if (text.length < 8) {
      return 'La contraseña no es válida';
    }
    return null;
  }

  String? _confirmValidator(String? value) {
    if (!_register) {
      return null;
    }
    if ((value ?? '') != _password.text) {
      return 'Las contraseñas no coinciden';
    }
    return null;
  }

  Future<void> _authenticate() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    if (_register && !_adultConfirmed) {
      _showMessage('Para crear una cuenta debes confirmar que tienes 18 años o más.');
      return;
    }
    if (_register && !_acceptedTerms) {
      _showMessage('Debes aceptar los Términos de uso y las Normas de la comunidad, y leer la Política de privacidad.');
      return;
    }

    setState(() => _busy = true);
    try {
      final auth = Supabase.instance.client.auth;
      if (_register) {
        final response = await auth.signUp(
          email: _email.text.trim(),
          password: _password.text,
          data: {
            'display_name': _displayName.text.trim(),
            'terms_version': AppConfig.termsVersion,
            'terms_accepted_at': DateTime.now().toUtc().toIso8601String(),
            'adult_confirmed_at': DateTime.now().toUtc().toIso8601String(),
          },
          emailRedirectTo: AppConfig.authRedirectUrl,
        );
        if (!mounted) {
          return;
        }
        if (response.session == null) {
          await _showInfoDialog(
            title: 'Confirma tu correo',
            body:
                'Te hemos enviado un enlace de confirmación. Abre el correo y confirma tu cuenta antes de iniciar sesión.',
          );
          if (mounted) {
            setState(() => _register = false);
          }
        } else {
          _finishAuth();
        }
      } else {
        await auth.signInWithPassword(
          email: _email.text.trim(),
          password: _password.text,
        );
        if (mounted) {
          _finishAuth();
        }
      }
    } on AuthException catch (error) {
      _showMessage(_friendlyAuthError(error.message));
    } catch (_) {
      _showMessage('No hemos podido completar el acceso. Inténtalo de nuevo.');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _finishAuth() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/profile');
    }
  }

  Future<void> _resetPassword() async {
    final error = _emailValidator(_email.text);
    if (error != null) {
      _showMessage('Escribe primero el email de tu cuenta.');
      return;
    }
    setState(() => _busy = true);
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        _email.text.trim(),
        redirectTo: '${AppConfig.websiteUrl}/auth/recovery',
      );
      if (!mounted) {
        return;
      }
      await _showInfoDialog(
        title: 'Revisa tu correo',
        body:
            'Si existe una cuenta con ese email, recibirás un enlace para establecer una contraseña nueva.',
      );
    } on AuthException catch (error) {
      _showMessage(_friendlyAuthError(error.message));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _resendConfirmation() async {
    final error = _emailValidator(_email.text);
    if (error != null) {
      _showMessage('Escribe primero el email de tu cuenta.');
      return;
    }
    setState(() => _busy = true);
    try {
      await Supabase.instance.client.auth.resend(
        type: OtpType.signup,
        email: _email.text.trim(),
        emailRedirectTo: AppConfig.authRedirectUrl,
      );
      if (!mounted) return;
      await _showInfoDialog(
        title: 'Correo reenviado',
        body: 'Si la cuenta está pendiente de confirmar, Supabase volverá a enviar el enlace de verificación.',
      );
    } on AuthException catch (error) {
      _showMessage(_friendlyAuthError(error.message));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showInfoDialog({required String title, required String body}) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  String _friendlyAuthError(String raw) {
    final value = raw.toLowerCase();
    if (value.contains('invalid login credentials')) {
      return 'Email o contraseña incorrectos.';
    }
    if (value.contains('email not confirmed')) {
      return 'Confirma tu email antes de iniciar sesión.';
    }
    if (value.contains('already registered') || value.contains('user already')) {
      return 'Ya existe una cuenta con ese email.';
    }
    if (value.contains('rate limit')) {
      return 'Demasiados intentos. Espera unos minutos y vuelve a probar.';
    }
    return 'No hemos podido completar el acceso. Revisa los datos e inténtalo de nuevo.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final desktop = constraints.maxWidth >= 900;
            return Row(
              children: [
                if (desktop)
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFFDDF7ED), Color(0xFFF4FBF8)],
                        ),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(44),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            GratisCashLogo(),
                            SizedBox(height: 32),
                            Text(
                              'Descubre oportunidades.\nGuarda las buenas.\nComparte las tuyas.',
                              style: TextStyle(
                                fontSize: 39,
                                height: 1.08,
                                fontWeight: FontWeight.w900,
                                color: GratisCashTheme.dark,
                                letterSpacing: -1.3,
                              ),
                            ),
                            SizedBox(height: 18),
                            Text(
                              'No necesitas una cuenta para mirar. Solo te la pedimos cuando quieras participar en la comunidad.',
                              style: TextStyle(
                                color: GratisCashTheme.muted,
                                fontSize: 16,
                                height: 1.5,
                              ),
                            ),
                            SizedBox(height: 26),
                            _AuthBenefit(
                              icon: Icons.bookmark_outline_rounded,
                              text: 'Guarda oportunidades para más tarde',
                            ),
                            _AuthBenefit(
                              icon: Icons.forum_outlined,
                              text: 'Vota y comenta con la comunidad',
                            ),
                            _AuthBenefit(
                              icon: Icons.add_circle_outline_rounded,
                              text: 'Propón oportunidades para revisión',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 470),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: _AuthForm(
                          formKey: _formKey,
                          register: _register,
                          busy: _busy,
                          acceptedTerms: _acceptedTerms,
                          adultConfirmed: _adultConfirmed,
                          showPassword: _showPassword,
                          showConfirmPassword: _showConfirmPassword,
                          displayName: _displayName,
                          email: _email,
                          password: _password,
                          confirmPassword: _confirmPassword,
                          displayNameValidator: _displayNameValidator,
                          emailValidator: _emailValidator,
                          passwordValidator: _passwordValidator,
                          confirmValidator: _confirmValidator,
                          onSubmit: _authenticate,
                          onReset: _resetPassword,
                          onResendConfirmation: _resendConfirmation,
                          onTermsChanged: (value) =>
                              setState(() => _acceptedTerms = value),
                          onAdultChanged: (value) =>
                              setState(() => _adultConfirmed = value),
                          onPasswordVisibility: () =>
                              setState(() => _showPassword = !_showPassword),
                          onConfirmVisibility: () => setState(
                            () => _showConfirmPassword = !_showConfirmPassword,
                          ),
                          onModeChanged: (register) {
                            HapticFeedback.selectionClick();
                            setState(() {
                              _register = register;
                              _acceptedTerms = false;
                              _adultConfirmed = false;
                            });
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AuthForm extends StatelessWidget {
  const _AuthForm({
    required this.formKey,
    required this.register,
    required this.busy,
    required this.acceptedTerms,
    required this.adultConfirmed,
    required this.showPassword,
    required this.showConfirmPassword,
    required this.displayName,
    required this.email,
    required this.password,
    required this.confirmPassword,
    required this.displayNameValidator,
    required this.emailValidator,
    required this.passwordValidator,
    required this.confirmValidator,
    required this.onSubmit,
    required this.onReset,
    required this.onResendConfirmation,
    required this.onTermsChanged,
    required this.onAdultChanged,
    required this.onPasswordVisibility,
    required this.onConfirmVisibility,
    required this.onModeChanged,
  });

  final GlobalKey<FormState> formKey;
  final bool register;
  final bool busy;
  final bool acceptedTerms;
  final bool adultConfirmed;
  final bool showPassword;
  final bool showConfirmPassword;
  final TextEditingController displayName;
  final TextEditingController email;
  final TextEditingController password;
  final TextEditingController confirmPassword;
  final String? Function(String?) displayNameValidator;
  final String? Function(String?) emailValidator;
  final String? Function(String?) passwordValidator;
  final String? Function(String?) confirmValidator;
  final VoidCallback onSubmit;
  final VoidCallback onReset;
  final VoidCallback onResendConfirmation;
  final ValueChanged<bool> onTermsChanged;
  final ValueChanged<bool> onAdultChanged;
  final VoidCallback onPasswordVisibility;
  final VoidCallback onConfirmVisibility;
  final ValueChanged<bool> onModeChanged;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Volver',
                onPressed: () => context.canPop() ? context.pop() : context.go('/'),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              const Spacer(),
              if (MediaQuery.sizeOf(context).width < 900) const GratisCashLogo(),
              const Spacer(),
              const SizedBox(width: 48),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            register ? 'Crea tu cuenta' : 'Bienvenido de nuevo',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w900,
              color: GratisCashTheme.dark,
              letterSpacing: -0.7,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            register
                ? 'Una cuenta te permite guardar, votar, comentar y proponer oportunidades.'
                : 'Entra para continuar donde lo dejaste.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: GratisCashTheme.muted, height: 1.4),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F3F5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _ModeButton(
                    label: 'Entrar',
                    selected: !register,
                    onTap: () => onModeChanged(false),
                  ),
                ),
                Expanded(
                  child: _ModeButton(
                    label: 'Crear cuenta',
                    selected: register,
                    onTap: () => onModeChanged(true),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: register
                ? Padding(
                    key: const ValueKey('display-name'),
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TextFormField(
                      controller: displayName,
                      validator: displayNameValidator,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.name],
                      decoration: const InputDecoration(
                        labelText: 'Nombre visible',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                    ),
                  )
                : const SizedBox.shrink(key: ValueKey('no-display-name')),
          ),
          TextFormField(
            controller: email,
            validator: emailValidator,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.mail_outline_rounded),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: password,
            validator: passwordValidator,
            obscureText: !showPassword,
            textInputAction: register ? TextInputAction.next : TextInputAction.done,
            onFieldSubmitted: register ? null : (_) => onSubmit(),
            autofillHints: [
              register ? AutofillHints.newPassword : AutofillHints.password,
            ],
            decoration: InputDecoration(
              labelText: 'Contraseña',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                tooltip: showPassword ? 'Ocultar contraseña' : 'Mostrar contraseña',
                onPressed: onPasswordVisibility,
                icon: Icon(
                  showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                ),
              ),
            ),
          ),
          if (register) ...[
            const SizedBox(height: 10),
            _PasswordStrength(controller: password),
            const SizedBox(height: 8),
            const Text(
              'Usa al menos 12 caracteres. Combina mayúsculas, minúsculas y números; añade símbolos para reforzarla.',
              style: TextStyle(color: GratisCashTheme.muted, fontSize: 12.5),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: confirmPassword,
              validator: confirmValidator,
              obscureText: !showConfirmPassword,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => onSubmit(),
              decoration: InputDecoration(
                labelText: 'Repite la contraseña',
                prefixIcon: const Icon(Icons.lock_reset_rounded),
                suffixIcon: IconButton(
                  tooltip: showConfirmPassword ? 'Ocultar contraseña' : 'Mostrar contraseña',
                  onPressed: onConfirmVisibility,
                  icon: Icon(
                    showConfirmPassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: adultConfirmed,
              onChanged: (value) => onAdultChanged(value ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text(
                'Confirmo que tengo 18 años o más',
                style: TextStyle(fontSize: 13.2, fontWeight: FontWeight.w700),
              ),
              subtitle: const Text(
                'Las cuentas de comunidad de GratisCash están reservadas a personas adultas.',
                style: TextStyle(fontSize: 11.8),
              ),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: acceptedTerms,
              onChanged: (value) => onTermsChanged(value ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              title: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text('Acepto los ', style: TextStyle(fontSize: 13.2)),
                  InkWell(
                    onTap: () => context.push('/legal/terms'),
                    child: const Text(
                      'Términos de uso',
                      style: TextStyle(
                        fontSize: 13.2,
                        color: GratisCashTheme.greenDark,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const Text(', las ', style: TextStyle(fontSize: 13.2)),
                  InkWell(
                    onTap: () => context.push('/legal/community'),
                    child: const Text(
                      'Normas de la comunidad',
                      style: TextStyle(
                        fontSize: 13.2,
                        color: GratisCashTheme.greenDark,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const Text(' y he leído la ', style: TextStyle(fontSize: 13.2)),
                  InkWell(
                    onTap: () => context.push('/legal/privacy'),
                    child: const Text(
                      'Política de privacidad',
                      style: TextStyle(
                        fontSize: 13.2,
                        color: GratisCashTheme.greenDark,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const Text('.', style: TextStyle(fontSize: 13.2)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: busy ? null : onSubmit,
            child: Text(
              busy ? 'Un momento…' : register ? 'Crear cuenta' : 'Iniciar sesión',
            ),
          ),
          if (!register) ...[
            const SizedBox(height: 6),
            TextButton(
              onPressed: busy ? null : onReset,
              child: const Text('He olvidado mi contraseña'),
            ),
            TextButton(
              onPressed: busy ? null : onResendConfirmation,
              child: const Text('No he recibido el correo de confirmación'),
            ),
          ],
          const SizedBox(height: 10),
          const Row(
            children: [
              Expanded(child: Divider()),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'Explorar no requiere cuenta',
                  style: TextStyle(color: GratisCashTheme.muted, fontSize: 12),
                ),
              ),
              Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: () => context.go('/'),
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('Seguir sin iniciar sesión'),
          ),
        ],
      ),
    );
  }
}

class _PasswordStrength extends StatelessWidget {
  const _PasswordStrength({required this.controller});

  final TextEditingController controller;

  int _score(String value) {
    var score = 0;
    if (value.length >= 12) score++;
    if (RegExp(r'[a-z]').hasMatch(value) && RegExp(r'[A-Z]').hasMatch(value)) score++;
    if (RegExp(r'[0-9]').hasMatch(value)) score++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(value)) score++;
    return score;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, child) {
        final score = _score(value.text);
        final String label;
        final Color color;
        if (score <= 1) {
          label = 'Débil';
          color = const Color(0xFFD45B64);
        } else if (score == 2) {
          label = 'Aceptable';
          color = const Color(0xFFC88A23);
        } else if (score == 3) {
          label = 'Buena';
          color = const Color(0xFF3D9A78);
        } else {
          label = 'Muy buena';
          color = GratisCashTheme.green;
        }
        return Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: score / 4,
                  minHeight: 6,
                  backgroundColor: const Color(0xFFE9EDF0),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Colors.white : Colors.transparent,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? GratisCashTheme.dark : GratisCashTheme.muted,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthBenefit extends StatelessWidget {
  const _AuthBenefit({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: GratisCashTheme.green, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: GratisCashTheme.dark,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
