import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Group page tabs, in the order they appear, by the name their URL uses.
const groupTabs = ['malumot', 'davomat', 'vazifalar', 'jurnal', 'reyting'];

/// Sends the app to [location].
///
/// Every screen has an address, and this is how the app moves between them.
/// [fallback] covers a widget built on its own outside the router — a widget
/// test pumping one screen — where it pushes the page the old way instead.
void goTo(BuildContext context, String location, {WidgetBuilder? fallback}) {
  final router = GoRouter.maybeOf(context);
  if (router != null) {
    router.go(location);
    return;
  }
  if (fallback != null) {
    Navigator.push(context, MaterialPageRoute<void>(builder: fallback));
  }
}

/// Goes back: up the router's own stack when there is one, otherwise to
/// [fallbackLocation], so a pasted link still has somewhere to go back to.
void goBack(BuildContext context, String fallbackLocation) {
  final router = GoRouter.maybeOf(context);
  if (router == null) {
    Navigator.maybePop(context);
    return;
  }
  if (router.canPop()) {
    router.pop();
    return;
  }
  router.go(fallbackLocation);
}

/// Like [goTo], but the fallback outside the router runs [instead] — for a
/// place whose old behaviour was a dialog rather than a page.
void goOr(BuildContext context, String location, VoidCallback instead) {
  final router = GoRouter.maybeOf(context);
  if (router != null) {
    router.go(location);
    return;
  }
  instead();
}

/// Whether the app is running under the router. False only for a widget
/// built on its own, such as one screen in a widget test.
bool isRouted(BuildContext context) => GoRouter.maybeOf(context) != null;

/// A person's own page. Their name is clickable wherever it is shown.
String profilePath(String userId) => '/profile/$userId';

String groupPath(String groupId, [String? tab]) =>
    tab == null ? '/groups/$groupId' : '/groups/$groupId/$tab';

String homeworkPath(String homeworkId) => '/homeworks/$homeworkId';

/// A person's name, clickable wherever it appears: it opens their profile.
class PersonName extends StatelessWidget {
  const PersonName({
    super.key,
    required this.userId,
    required this.name,
    this.style = const TextStyle(fontWeight: FontWeight.w600),
  });

  final String userId;
  final String name;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(8),
    onTap: () => goTo(context, profilePath(userId)),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      child: Text(name, style: style, overflow: TextOverflow.ellipsis),
    ),
  );
}
