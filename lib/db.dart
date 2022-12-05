import 'package:logging/logging.dart';
import 'package:sembast/sembast.dart';
import 'package:sembast/sembast_io.dart';

final _logger = Logger('DB');

final challenges = StoreRef<int, List<Object?>>('challenges');
final scores = StoreRef<int, int>('scores');
final messageHistory = StoreRef<String, String>('messagehistory');
late Database db;

Future<void> setup() async {
  db = await databaseFactoryIo
      .openDatabase('.dart_tool/sembast/parry-bot.db')
      .whenComplete(() => _logger.info("Database connection has been opened."));
}
