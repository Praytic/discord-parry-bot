// GENERATED CODE - DO NOT MODIFY BY HAND
// Copyright 2021 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'dart:async';
import 'dart:io';

import 'package:nyxx/nyxx.dart';

void main() {
  final duelmap = <Snowflake, List<Snowflake>>{};
  final scores = <Snowflake, int>{};

  final token = Platform.environment['TOKEN'];
  final bot = NyxxFactory.createNyxxWebsocket(token!,
      GatewayIntents.guildMessageReactions | GatewayIntents.guildMessages)
    ..registerPlugin(Logging()) // Default logging plugin
    ..registerPlugin(
        CliIntegration()) // Cli integration for nyxx allows stopping application via SIGTERM and SIGKILl
    ..registerPlugin(
        IgnoreExceptions()) // Plugin that handles uncaught exceptions that may occur
    ..connect();

  // Listen for message events
  bot.eventsWs.onMessageReceived.listen((event) async {
    if (event.message.content.contains('парируй')) {
      final mentions = await Future.wait(
          event.message.mentions.map((e) async => e.getOrDownload()));
      final author = await event.message.member?.user.getOrDownload();
      if (author != null) {
        duelmap.putIfAbsent(author.id, () => []);
        final duelists =
            mentions.map((e) => e.id).where((e) => e != author.id).toList();
        duelmap[author.id]?.addAll(duelists);
      }
    }
  });

  bot.eventsWs.onSelfMention.listen((event) async {
    final user = await event.message.member?.user.getOrDownload();
    final username = user?.username;
    final score = scores[user] ?? 0;
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
        final parried =
            duelmap[reactionAuthor.id]?.remove(messageAuthor.id) ?? false;
        if (parried) {
          final score = scores.putIfAbsent(messageAuthor.id, () => 0);
          scores[messageAuthor.id] = score + 1;
          // await message.deleteUserReaction(event.emoji, message);
        }
      }
    }
  });
}