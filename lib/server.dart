// GENERATED CODE - DO NOT MODIFY BY HAND
// Copyright 2021 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the 'License');
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an 'AS IS' BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

// ignore_for_file: prefer_single_quotes

import 'package:logging/logging.dart';
import 'package:sembast/sembast.dart';

import 'db.dart' as db;
import 'httpserver.dart' as httpserver;
import 'bot.dart' as bot;
import 'logging.dart' as logging;

void main() async {
  logging.setup();
  await db.setup();
  await httpserver.setup();
  bot.setup();
}
