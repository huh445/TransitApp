import 'transit_type.dart';

enum PtvMode {
  regionalTrain('1'),
  metroTrain('2'),
  metroTram('3'),
  metroBus('4'),
  regionalCoach('5'),
  regionalBus('6');

  final String id;
  const PtvMode(this.id);

  int get ptvRouteType {
    switch (this) {
      case PtvMode.metroTrain:
        return 0;
      case PtvMode.metroTram:
        return 1;
      case PtvMode.metroBus:
      case PtvMode.regionalBus:
        return 2;
      case PtvMode.regionalTrain:
      case PtvMode.regionalCoach:
        return 3;
    }
  }

  TransitType get transitType {
    switch (this) {
      case PtvMode.metroTrain:
        return TransitType.metro;
      case PtvMode.metroTram:
        return TransitType.tram;
      case PtvMode.regionalTrain:
        return TransitType.regionalTrain;
      case PtvMode.metroBus:
      case PtvMode.regionalBus:
        return TransitType.bus;
      case PtvMode.regionalCoach:
        return TransitType.ferry;
    }
  }

  static PtvMode fromTransitType(TransitType type) {
    switch (type) {
      case TransitType.metro:
        return PtvMode.metroTrain;
      case TransitType.tram:
        return PtvMode.metroTram;
      case TransitType.regionalTrain:
        return PtvMode.regionalTrain;
      case TransitType.bus:
        return PtvMode.metroBus;
      case TransitType.ferry:
        return PtvMode.regionalCoach;
    }
  }
}
