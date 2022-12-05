import 'dart:async';
import 'dart:io';

import 'package:tuple/tuple.dart';
import 'package:logging/logging.dart';
import 'package:nyxx/nyxx.dart';
import 'package:sembast/sembast.dart';

import 'Battlefield.dart';
import 'db.dart';

Logger _logger = Logger('Bot Operations');
Battlefield battlefield = Battlefield(challenges);

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

List<Snowflake> getGuilds(INyxxWebsocket bot) {
  return bot.shardManager.shards
      .map((element) => element.guilds)
      .expand((element) => element)
      .toList();
}

Iterable<String> mergeMessages(Iterable<IMessage> messages) {
  final firstMessage = messages.first;
  final resultMessages = List<String>.empty(growable: true);

  var currentAuthor = firstMessage.author;
  var messageBuilder = StringBuffer(firstMessage.content);
  for (final message in messages.skip(1)) {
    if (message.author == currentAuthor) {
      messageBuilder.write(" ${message.content}");
    } else {
      resultMessages.add("${currentAuthor.username}: ${messageBuilder.toString().replaceAll(RegExp(r'<.+?>'), "").replaceAll(RegExp(r'https?://(www\.)?[-a-zA-Z0-9@:%._+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_+.~#?&//=]*)'), "")}");
      currentAuthor = message.author;
      messageBuilder = StringBuffer(message.content);
    }
  }
  return resultMessages;
}

Iterable<IGuildChannel> getChannels(INyxxWebsocket bot, Snowflake guildId) {
  return List.empty();
}

Future<String> getChannelHistory(INyxxWebsocket bot, String channelName) async {
  return await db.transaction((txn) async {
    return await messageHistory.record(channelName).get(txn) ?? "";
  });
}

void _setupOperations(INyxxWebsocket bot) {
  bot.eventsWs.onMessageReceived.listen((event) async {
    // await messages.record(event.message.channel!.id.id).get(db) ?? 0;
    if (battlefield.hasMentionOfChallenge(event.message)) {
      await battlefield.handleChallenge(event.message);
    } else if (await battlefield.isUserChallenged(event.message.author)) {
      if (await battlefield.isTryingToParryByReply(event.message)) {
        await battlefield.handleParry(
            event.message, event.message.referencedMessage!.message!.author);
      }
      // } else if (await battlefield.isTryingToParrySlowly(event.message)) {
      //   await battlefield.handleParry(event.message);
      // }
    }
  });

  bot.eventsWs.onMessageReceived.listen((event) async {
    if (event.message.content == "tl;dr") {
      _logger.log(
          Level.INFO,
          "${event.message.author} requested tl;dr of all recent messages in channel " +
              "${event.message.channel}");
      final channel = await event.message.channel.getOrDownload();
      final createdAt = event.message.createdAt;
      var flag = true;
      var currentMessage = event.message;
      var traversedMessagesCount = 0;
      _logger.log(Level.INFO, "Start traversing messages for ${channel}...");
      final resultMessages = List<IMessage>.empty(growable: true);
      while (flag) {
        final messagesBatch = await channel
            .downloadMessages(limit: 100, before: currentMessage.id)
            .where((m) {
              final isAfter = m.createdAt
                  .isAfter(createdAt.subtract(const Duration(days: 1)));
              if (flag && !isAfter) flag = false;
              return isAfter;
            })
            .map((m) => new Tuple2<IMessage, DateTime>(m, m.createdAt))
            .toList();
        traversedMessagesCount += messagesBatch.length;
        currentMessage = messagesBatch
            .reduce(
                (curr, next) => curr.item2.isBefore(next.item2) ? curr : next)
            .item1;
        resultMessages.addAll(messagesBatch.map((e) => e.item1));
      }
      _logger.log(
          Level.INFO,
          "Finish traversing messages for ${channel}. "
          "Messages traversed: ${traversedMessagesCount}");
      await db.transaction((txn) async {
        final text = mergeMessages(resultMessages).join("\n");
        final String channelTopic;
        if (channel is ITextGuildChannel) {
          channelTopic = channel.name;
        } else {
          channelTopic = "Other";
        }
        if (await messageHistory.record(channelTopic).exists(txn)) {
          await messageHistory.record(channelTopic).update(txn, text);
        } else {
          await messageHistory.record(channelTopic).put(txn, text);
        }
      });
    }
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
      await battlefield.handleParry(message, reactionAuthor);
    }
  });
}

String? _hideCreds(String? creds) =>
    creds?.replaceRange(4, creds.length - 4, '*' * (creds.length - 8));
