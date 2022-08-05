import 'package:logging/logging.dart';
import 'package:nyxx/nyxx.dart';
import 'package:sembast/sembast.dart';
import 'package:collection/collection.dart';

import 'db.dart';

class Battlefield {
  Logger _logger = Logger('Battlefield');

  Future<bool> _parry(
      SnowflakeEntity parrier, SnowflakeEntity challenger) async {
    if (parrier.id == challenger.id) {
      return false;
    }
    return await db.transaction((txn) async {
      final parriers = await challenges.record(challenger.id.id).get(txn);
      final mutableParriers = parriers?.toList();
      final parried = mutableParriers?.remove(parrier.id.id) ?? false;
      if (parried) {
        await challenges.record(challenger.id.id).put(txn, mutableParriers!);
        final score = await scores.record(parrier.id.id).get(txn) ?? 0;
        await scores.record(parrier.id.id).put(txn, score + 1);
      }
      return parried;
    });
  }

  Future<bool> hasMentionOfParrier(
      IMessageAuthor parrier, IMessage message) async {
    final mentions =
        await Future.wait(message.mentions.map((e) async => e.getOrDownload()));
    return mentions.any((user) => user.id == parrier.id);
  }

  bool hasMentionOfChallenge(IMessage message) =>
      message.content.contains('парируй');

  Future<bool> isTryingToParry(IMessage message) async {
    if (!(message.referencedMessage?.exists ?? false)) {
      return false;
    }

    final challenger = message.referencedMessage!.message!.author;
    final parrier = message.author;
    final challengeMessage = message.referencedMessage!.message!;

    final nearestMessages = await challengeMessage.channel
        .downloadMessages(around: challengeMessage.id)
        .toList()
      ..where((msg) => msg.author == challenger).sortedBy(
          (msg) => msg.createdAt.difference(challengeMessage.createdAt));

    final hasMentionOfParrier = await Stream.fromFutures(nearestMessages
            .map((msg) async => await this.hasMentionOfParrier(parrier, msg)))
        .any((element) => element);
    final hasMentionOfChallenge =
        nearestMessages.any((msg) => this.hasMentionOfChallenge(msg));
    return hasMentionOfChallenge && hasMentionOfParrier;
  }

  Future<void> handleParry(
      IMessage parryMessage, IMessageAuthor challenger) async {
    final parrier = parryMessage.author;
    final parried = await _parry(parrier, challenger);
    if (parried) {
      _logger.log(
          Level.FINE,
          "${parrier.username} parried ${challenger.username}'s "
          "challenge");
    }
  }

  Future<void> handleChallenge(IMessage message) async {
    final challenger = await message.member?.user.getOrDownload();
    if (challenger == null) {
      throw Exception('Challenger is not a member of a channel.');
    }

    late Iterable<IUser> challengedUsers;
    if (message.mentions.isNotEmpty) {
      // Message has challenged users mentions
      challengedUsers = await Future.wait(
          message.mentions.map((e) async => e.getOrDownload()));
    } else {
      // Message doesn't have challenged users mentions
      // Will search for message with mention in the nearest messages
      challengedUsers = await Future.delayed(const Duration(seconds: 5),
          () => getChallengedUsers(challenger, message));
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
}
