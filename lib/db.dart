import 'package:logging/logging.dart';
import 'package:sembast/sembast.dart';
import 'package:sembast/sembast_io.dart';

final _logger = Logger('httpserver');

final challenges = StoreRef<int, List<Object?>>('challenges');
final scores = StoreRef<int, int>('scores');
late Database db;

Future<void> setup() async {
  db = await databaseFactoryIo
      .openDatabase('.dart_tool/sembast/parry-bot.db')
      .whenComplete(() => _logger.info("Database connection has been opened."));
}
