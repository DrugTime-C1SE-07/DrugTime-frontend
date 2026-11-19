import 'package:app_links/app_links.dart';

/// Link mở app từ bên ngoài (Android App Links), gồm cả link đã mở app lúc khởi động.
abstract interface class InviteLinkSource {
  Stream<Uri> get links;
}

class AppLinksInviteLinkSource implements InviteLinkSource {
  AppLinksInviteLinkSource([AppLinks? appLinks]) : _appLinks = appLinks ?? AppLinks();

  final AppLinks _appLinks;

  // `uriLinkStream` phát cả link khởi động lẫn các link sau đó.
  @override
  Stream<Uri> get links => _appLinks.uriLinkStream;
}
