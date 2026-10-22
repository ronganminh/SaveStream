import 'package:url_launcher/url_launcher.dart';

import 'config/app_config.dart';

/// Opens [url] outside the app (browser, Play Store, mail app). Returns
/// whether something opened it.
Future<bool> openExternalUrl(Uri url) async {
  try {
    return await launchUrl(url, mode: LaunchMode.externalApplication);
  } on Object {
    // Nothing to open it with; the screen stays as it is.
    return false;
  }
}

/// Opens the mail app with a message to [address].
Future<bool> openMail(String address, {String? subject}) =>
    openExternalUrl(AppConfig.mailto(address, subject: subject));

/// The app's Play Store listing (the Play Store app, else the web page).
Future<bool> openPlayStoreListing() async {
  if (await openExternalUrl(AppConfig.playStoreAppUrl)) return true;
  return openExternalUrl(AppConfig.playStoreWebUrl);
}
