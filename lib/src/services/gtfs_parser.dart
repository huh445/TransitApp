import 'dart:io';
import 'package:gtfs_bindings/schedule.dart' as gtfs;
import 'package:gtfs_realtime_bindings/gtfs_realtime_bindings.dart' as gtfs_rt;
import '../models/transit_route.dart';

/// Service for parsing GTFS Static and GTFS Realtime feeds into app models.
class GtfsParser {
  /// Opens a static GTFS schedule from a local Directory containing PTV GTFS files.
  static gtfs.DirectoryDataset openStaticDirectory(Directory directory) {
    return gtfs.DirectoryDataset(directory: directory);
  }

  /// Parses raw binary protobuf data from a GTFS-Realtime feed.
  static gtfs_rt.FeedMessage parseRealtimeFeed(List<int> bytes) {
    return gtfs_rt.FeedMessage.fromBuffer(bytes);
  }

  /// Extracts ServiceAlert models from a GTFS-Realtime FeedMessage.
  static List<ServiceAlert> parseServiceAlerts(gtfs_rt.FeedMessage feed) {
    final alerts = <ServiceAlert>[];

    for (final entity in feed.entity) {
      if (entity.hasAlert()) {
        final alert = entity.alert;
        final headerText = alert.headerText.translation.isNotEmpty
            ? alert.headerText.translation.first.text
            : 'Melbourne Network Alert';
        final descriptionText = alert.descriptionText.translation.isNotEmpty
            ? alert.descriptionText.translation.first.text
            : '';

        final lineCode = alert.informedEntity.isNotEmpty
            ? alert.informedEntity.first.routeId
            : 'PTV Network';

        final timestampSeconds = alert.activePeriod.isNotEmpty
            ? alert.activePeriod.first.start.toInt()
            : (DateTime.now().millisecondsSinceEpoch ~/ 1000);

        alerts.add(
          ServiceAlert(
            id: entity.id,
            title: headerText,
            description: descriptionText,
            lineCode: lineCode,
            timestamp: DateTime.fromMillisecondsSinceEpoch(timestampSeconds * 1000),
            severity: ServiceStatus.disrupted,
          ),
        );
      }
    }

    return alerts;
  }
}
