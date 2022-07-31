import 'package:logging/logging.dart';

void setup() {
  Logger.root.level = Level.FINE;
  Logger.root.onRecord.listen((LogRecord rec) async {
    print('[${rec.time}] [${rec.level}] [${rec.loggerName}] ${rec.message}\n');
  });
}
