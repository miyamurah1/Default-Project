import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

/// Home-screen widget bridge: "Today's plan" top-3 on the launcher.
///
/// - Android renders the classic `PlanWidgetProvider` RemoteViews;
/// - iOS renders the WidgetKit `PlanWidget` extension.
/// Both read the same keys below through the shared [kPlanWidgetGroupId]
/// defaults. Taps deliver `dailybloom://` URIs back to the app (cold
/// start via [initialLaunchUri], warm via [HomeWidget.widgetClicked]);
/// [parsePlanWidgetUri] turns them into navigation intents.
///
/// Off Android/iOS (web, desktop, tests) every call degrades to a
/// no-op `false` — the widget simply never appears there.
class PlanWidgetBridge {
  /// iOS App Group shared by Runner + the widget extension. Android
  /// ignores it (plugin-private prefs). Must match both entitlements
  /// and `PlanWidget.swift`.
  static const kPlanWidgetGroupId = 'group.com.dailybloom.app.plan';

  /// Native widget names. Must match the Android receiver /
  /// `res/xml/plan_widget_info.xml` and the iOS `Widget` kind.
  static const kAndroidWidgetName = 'PlanWidgetProvider';
  static const kIOSWidgetName = 'PlanWidget';

  /// Deep-link scheme for widget taps. Never leaves the device.
  static const kScheme = 'dailybloom';

  static bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// One widget row: a planned task + its reason + done state.
  /// Keep titles short — launchers ellipsize past one line.
  static Future<bool> pushPlan(
    List<({String id, String title, String reason, bool done})> rows,
  ) async {
    if (!_supported) return false;
    try {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await HomeWidget.setAppGroupId(kPlanWidgetGroupId);
      }
      final visible = rows.take(3).toList();
      await HomeWidget.saveWidgetData<int>('plan_count', visible.length);
      for (var i = 0; i < 3; i++) {
        final row = i < visible.length ? visible[i] : null;
        await HomeWidget.saveWidgetData<String>(
            'plan_${i}_id', row?.id ?? '');
        await HomeWidget.saveWidgetData<String>(
            'plan_${i}_title', row?.title ?? '');
        await HomeWidget.saveWidgetData<String>(
            'plan_${i}_reason', row?.reason ?? '');
        await HomeWidget.saveWidgetData<bool>(
            'plan_${i}_done', row?.done ?? false);
      }
      await HomeWidget.updateWidget(
        androidName: kAndroidWidgetName,
        iOSName: kIOSWidgetName,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// URI the app was cold-started with via a widget tap, if any.
  static Future<Uri?> initialLaunchUri() async {
    if (!_supported) return null;
    try {
      return await HomeWidget.initiallyLaunchedFromHomeWidget();
    } catch (_) {
      return null;
    }
  }

  static String taskUri(String id) => '$kScheme://task/$id';
  static const String planUri = '$kScheme://plan';

  /// `dailybloom://task/<id>` or `dailybloom://plan`, else null.
  /// Pure function — unit-tested, no platform calls.
  static ({String type, String? id})? parsePlanWidgetUri(Uri? uri) {
    if (uri == null || uri.scheme != kScheme) return null;
    if (uri.host == 'task' && uri.pathSegments.isNotEmpty) {
      return (type: 'task', id: uri.pathSegments.first);
    }
    if (uri.host == 'plan') return (type: 'plan', id: null);
    return null;
  }
}
