import 'dart:async';

import 'package:flutter/material.dart';

import '../app_state.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.state});

  static const defaultServer = 'http://192.168.31.188:3000';

  final AppState state;
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final server = TextEditingController(text: LoginScreen.defaultServer);
  final username = TextEditingController();
  final password = TextEditingController();
  final formKey = GlobalKey<FormState>();
  bool obscure = true;
  bool rememberPassword = false;
  bool loadingSavedCredentials = true;

  @override
  void initState() {
    super.initState();
    _restoreSavedCredentials();
  }

  Future<void> _restoreSavedCredentials() async {
    final saved = await widget.state.loadSavedCredentials();
    if (!mounted) return;
    setState(() {
      if (saved != null) {
        server.text = saved.server;
        username.text = saved.username;
        password.text = saved.password;
        rememberPassword = true;
      }
      loadingSavedCredentials = false;
    });
  }

  @override
  void dispose() {
    server.dispose();
    username.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!formKey.currentState!.validate()) return;
    final loggedIn = await widget.state.login(
      server.text,
      username.text,
      password.text,
      rememberPassword: rememberPassword,
    );
    if (loggedIn && !rememberPassword) password.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;
          return Row(
            children: [
              if (wide) const Expanded(flex: 5, child: _LoginBrandPanel()),
              Expanded(
                flex: wide ? 4 : 1,
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(24),
                  child: SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 430),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Form(
                          key: formKey,
                          child: AutofillGroup(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (!wide) ...[
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Container(
                                      width: 52,
                                      height: 52,
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: const Icon(
                                        Icons.rocket_launch_rounded,
                                        color: Colors.white,
                                        size: 28,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Rocket.Chat',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                  const Text('Flutter 跨平台客户端'),
                                  const SizedBox(height: 24),
                                ],
                                Text(
                                  '欢迎回来',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.5,
                                      ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '登录 Rocket.Chat，继续你的团队协作',
                                  style: Theme.of(context).textTheme.bodyLarge
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                      ),
                                ),
                                const SizedBox(height: 32),
                                TextFormField(
                                  controller: server,
                                  decoration: const InputDecoration(
                                    labelText: '服务器地址',
                                    prefixIcon: Icon(Icons.dns_outlined),
                                  ),
                                  keyboardType: TextInputType.url,
                                  validator: (value) =>
                                      value == null || value.trim().isEmpty
                                      ? '请输入服务器地址'
                                      : null,
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: username,
                                  autofillHints: const [AutofillHints.username],
                                  decoration: const InputDecoration(
                                    labelText: '用户名或邮箱',
                                    prefixIcon: Icon(
                                      Icons.person_outline_rounded,
                                    ),
                                  ),
                                  validator: (value) =>
                                      value == null || value.trim().isEmpty
                                      ? '请输入账号'
                                      : null,
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: password,
                                  autofillHints: const [AutofillHints.password],
                                  obscureText: obscure,
                                  onFieldSubmitted: (_) => submit(),
                                  decoration: InputDecoration(
                                    labelText: '密码',
                                    prefixIcon: const Icon(
                                      Icons.lock_outline_rounded,
                                    ),
                                    suffixIcon: IconButton(
                                      tooltip: obscure ? '显示密码' : '隐藏密码',
                                      onPressed: () =>
                                          setState(() => obscure = !obscure),
                                      icon: Icon(
                                        obscure
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                      ),
                                    ),
                                  ),
                                  validator: (value) =>
                                      value == null || value.isEmpty
                                      ? '请输入密码'
                                      : null,
                                ),
                                const SizedBox(height: 8),
                                CheckboxListTile(
                                  contentPadding: EdgeInsets.zero,
                                  value: rememberPassword,
                                  onChanged: loadingSavedCredentials
                                      ? null
                                      : (value) {
                                          setState(
                                            () => rememberPassword =
                                                value ?? false,
                                          );
                                          if (value != true) {
                                            unawaited(
                                              widget.state
                                                  .clearSavedCredentials(),
                                            );
                                          }
                                        },
                                  title: const Text('保存密码'),
                                  subtitle: const Text('使用系统安全凭据存储，下次启动自动回填'),
                                  controlAffinity:
                                      ListTileControlAffinity.leading,
                                ),
                                if (widget.state.error != null)
                                  Container(
                                    margin: const EdgeInsets.only(top: 10),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .errorContainer,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(widget.state.error!),
                                  ),
                                const SizedBox(height: 22),
                                FilledButton.icon(
                                  onPressed: widget.state.busy ? null : submit,
                                  icon: widget.state.busy
                                      ? const SizedBox.square(
                                          dimension: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.arrow_forward_rounded),
                                  label: const Text('登录'),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  '未启用“保存密码”时，密码只用于本次登录。',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                if (wide) ...[
                                  const SizedBox(height: 20),
                                  const Text(
                                    'Rocket.Chat · Flutter 跨平台客户端',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LoginBrandPanel extends StatelessWidget {
  const _LoginBrandPanel();

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.all(18),
    padding: const EdgeInsets.all(56),
    decoration: BoxDecoration(
      color: const Color(0xff17182b),
      borderRadius: BorderRadius.circular(30),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: const Color(0xff6868df),
            borderRadius: BorderRadius.circular(17),
          ),
          child: const Icon(
            Icons.rocket_launch_rounded,
            color: Colors.white,
            size: 30,
          ),
        ),
        const Spacer(),
        const Text(
          'Rocket.Chat',
          style: TextStyle(
            color: Colors.white,
            fontSize: 40,
            fontWeight: FontWeight.w800,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          '让团队沟通更专注、更顺畅。',
          style: TextStyle(color: Color(0xffc7cadc), fontSize: 20, height: 1.5),
        ),
        const SizedBox(height: 36),
        const Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _FeaturePill(icon: Icons.bolt_rounded, label: '实时消息'),
            _FeaturePill(icon: Icons.devices_rounded, label: '全平台'),
            _FeaturePill(icon: Icons.lock_outline_rounded, label: '安全登录'),
          ],
        ),
        const Spacer(),
        const Text(
          'Flutter 跨平台客户端',
          style: TextStyle(color: Color(0xff888ca8), fontSize: 13),
        ),
      ],
    ),
  );
}

class _FeaturePill extends StatelessWidget {
  const _FeaturePill({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: const Color(0xff242640),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xff353753)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: const Color(0xff9797f5), size: 18),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(color: Color(0xffd8daea))),
      ],
    ),
  );
}
