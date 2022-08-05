import 'dart:io';

import 'package:collection/collection.dart';
import 'package:logging/logging.dart';
import 'package:nyxx/nyxx.dart';
import 'package:sembast/sembast.dart';

import 'db.dart';

Logger _logger = Logger('operations');
PriorityQueue<IMessage> recentMessages =
    PriorityQueue<IMessage>((a, b) => b.createdAt.compareTo(a.createdAt));

INyxxWebsocket setup() {
  final token = Platform.environment['TOKEN'];
  final bot = NyxxFactory.createNyxxWebsocket(token!,
      GatewayIntents.guildMessageReactions | GatewayIntents.guildMessages)
    ..registerPlugin(Logging()) // Default logging plugin
    ..registerPlugin(
        CliIntegration()) // Cli integration for nyxx allows stopping application via SIGTERM and SIGKILl
    ..registerPlugin(
        IgnoreExceptions()) // Plugin that handles uncaught exceptions that may occur
    ..connect().whenComplete(() => _logger.log(
        Level.INFO,
        "Bot initialization is complete. "
        "Discord token: ${_hideCreds(token)}"));
  _setupOperations(bot);
  return bot;
}

void _setupOperations(INyxxWebsocket bot) {
  bot.eventsWs.onMessageReceived.listen((event) async {
    if (!event.message.content.contains('парируй')) {
      return;
    }

    final challenger = await event.message.member?.user.getOrDownload();
    if (challenger == null) {
      throw Exception('Challenger is not a member of a channel.');
    }

    late Iterable<IUser> challengedUsers;
    if (event.message.mentions.isNotEmpty) {
      // Message has challenged users mentions
      challengedUsers = await Future.wait(
          event.message.mentions.map((e) async => e.getOrDownload()));
    } else {
      // Message doesn't have challenged users mentions
      // Will search for message with mention in the nearest messages
      challengedUsers = await Future.delayed(const Duration(seconds: 5),
          () => getChallengedUsers(challenger, event.message));
    }

    // Add challenged users (mentioned by the [challenger]) to the
    // [challenges] table in the [db]
    challengedUsers.map((e) => e.id).where((e) => e != challenger.id).forEach(
        (e) async =>
            challenges.record(challenger.id.id).put(db, [e.id], merge: true));
    final challengedUsernames = challengedUsers
        .map((e) => e.username)
        .where((e) => e != challenger.username);

    _logger.log(
        Level.FINE, "${challenger.username} challenged ${challengedUsernames}");
  });

  bot.eventsWs.onSelfMention.listen((event) async {
    final user = await event.message.member?.user.getOrDownload();

    final username = user?.username;
    final score = await scores.record(user!.id.id).get(db) ?? 0;
    if (username != null) {
      await event.message.channel.sendMessage(MessageBuilder.embed(
          EmbedBuilder()..description = '$username спарировал $score раз'));
    }
  });

  bot.eventsWs.onMessageReactionAdded.listen((event) async {
    if (event.emoji.encodeForAPI() == '⚔️') {
      final message = await event.channel.fetchMessage(event.messageId);
      final reactionAuthor = await event.user.getOrDownload();
      final messageAuthor = message.author;
      if (messageAuthor.id != reactionAuthor.id) {
        await db.transaction((txn) async {
          final parriers =
              await challenges.record(reactionAuthor.id.id).get(txn);
          final mutableParriers = parriers?.toList();
          final parried = mutableParriers?.remove(messageAuthor.id.id) ?? false;
          if (parried) {
            await challenges
                .record(reactionAuthor.id.id)
                .put(txn, mutableParriers!);
            final score =
                await scores.record(messageAuthor.id.id).get(txn) ?? 0;
            await scores.record(messageAuthor.id.id).put(txn, score + 1);
// await message.deleteUserReaction(event.emoji, message);
            _logger.log(
                Level.FINE,
                "${messageAuthor.username} parried ${reactionAuthor.username}'s "
                "challenge");
          }
        });
      }
    }
  });
}

Future<Iterable<IUser>> getChallengedUsers(
    IUser challenger, IMessage challengeMessage) async {
  // Less than 100 messages posted in this channel by the same user
  // who started a challenge for parry
  final nearestMessages = await challengeMessage.channel
      .downloadMessages(around: challengeMessage.id)
      .toList()
    ..where((msg) => msg.author == challenger).sortedBy(
        (msg) => msg.createdAt.difference(challengeMessage.createdAt));

  // closest (earlier or later) message to the parry message with mentions
  final mentionsForParry = nearestMessages
          .firstWhereOrNull((msg) => msg.mentions.isNotEmpty)
          ?.mentions
          .map((e) async => e.getOrDownload()) ??
      const Iterable.empty();
  return Future.wait(mentionsForParry);
}

String? _hideCreds(String? creds) =>
    creds?.replaceRange(4, creds.length - 4, '*' * (creds.length - 8));
