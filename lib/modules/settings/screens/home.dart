import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lex/modules/settings/widgets/tile.dart';
import 'package:lex/providers/cms.dart';
import 'package:lex/providers/impartus.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:receive_intent/receive_intent.dart' as receive_intent;

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
        leading: BackButton(
          onPressed: () {
            context.go('/cms');
          },
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ListView(
            children: const [_ImpartusSettings(), _CMSSettings()],
          ),
        ),
      ),
    );
  }
}

class _ImpartusSettings extends ConsumerWidget {
  const _ImpartusSettings();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(impartusSettingsProvider);
    final settingsNotifier = ref.watch(impartusSettingsProvider.notifier);
    return SettingsTile(
      title: "Impartus",
      children: [
        TextFormField(
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.email),
            labelText: "E-Mail",
            hintText: "f20XXXXXX@hyderabad.bits-pilani.ac.in",
          ),
          initialValue: settings.email,
          onFieldSubmitted: (value) {
            settingsNotifier.setEmail(value);
          },
        ),
        TextFormField(
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.password),
            labelText: "Password",
          ),
          initialValue: settings.password,
          onFieldSubmitted: (value) {
            settingsNotifier.setPassword(value);
          },
        ),
      ],
    );
  }
}

class _CMSSettings extends ConsumerWidget {
  const _CMSSettings();

  Future<void> _showTokenHelpDialog(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 8),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "1. Login to the official CMS using your web browser",
                ),
                const Text("2. Go Account > Preferences > Security Keys"),
                TextButton(
                  onPressed: () => launchUrlString(
                    "https://cms.bits-hyderabad.ac.in/user/managetoken.php",
                  ),
                  child: const Text("Manage your Security Tokens"),
                ),
                const Text(
                  "3. Click on the 'Reset' button on the 'Moodle mobile web service' key",
                ),
                const Text(
                  "4. Copy and paste the new 'Moodle mobile web service' key over here.",
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = ref.watch(cmsClientProvider);
    final token = ref.watch(cmsTokenProvider);
    return SettingsTile(
      title: "CMS",
      children: [
        TextFormField(
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.token),
            labelText: "Web service token",
            suffixIcon: IconButton(
              onPressed: () => _showTokenHelpDialog(context),
              icon: const Icon(Icons.help),
            ),
          ),
          initialValue: token,
          onFieldSubmitted: (value) {
            ref.read(cmsTokenProvider.notifier).state = value;
          },
        ),
        TextButton(
          onPressed: () {
            client.registerUserDevice().then((value) => showDialog(
                context: context,
                builder: (context) =>
                    AlertDialog(content: Text(value.toString()))));
          },
          child: const Text("reg notif"),
        ),
        TextButton(
          onPressed: () {
            client.unregisterUserDevice().then((value) => showDialog(
                context: context,
                builder: (context) =>
                    AlertDialog(content: Text(value.toString()))));
          },
          child: const Text("unreg notif"),
        ),
        TextButton(
          onPressed: () {
            Random random = Random();
            int passport = random.nextInt(1000);

            launchUrlString(
              "https://cms.bits-hyderabad.ac.in/admin/tool/mobile/launch.php?service=moodle_mobile_app&oauthsso=1&passport=$passport&urlscheme=lectern",
              mode: LaunchMode.externalApplication,
            );

            receive_intent.ReceiveIntent.receivedIntentStream
                .listen((receive_intent.Intent? intent) {
              String token = utf8
                  .decode(base64Decode(intent!.data!.split("token=")[1]))
                  .split(":::")[1];
              // showDialog(
              //   context: context,
              //   builder: (context) => AlertDialog(content: Text(token)),
              // );
              ref.read(cmsTokenProvider.notifier).state = token;
            });
          },
          child: const Text("Login with Google"),
        ),
      ],
    );
  }
}
