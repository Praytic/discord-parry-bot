# Discord Parry Bot

Private bot for private use. In short, it tracks the number of "parried" challenges given by guild members to each other,
for example: 
- "@oliver129, парируй"
- *sends controversial pic*
- "@matew310, да это фейк"
- *@matew310 parried @oliver129's challenge*

At the end of the day challenge timer should run out if the user who was challenged can't parry. This means he doesn't get
a point for that. All users who ever participated in a parry challenge have a stored score. This score can be printed into
the guild message channel if a user tags the bot:
- `@parry-bot`
- "@matew310 спарировал 100500 раз"

## Build & Deployment

For local use you can either build with docker: 
```shell
$ docker build . -t discord-bot --build-arg DISCORD_TOKEN=<token>

$ docker run -it -p 8080:80 --name app discord-bot
```

...or without docker:
```shell
$ dart pub get --offline

$ dart compile exe lib/server.dart -o build/discord-bot

$ TOKEN=<token> build/discord-bot
```

...or you can deploy to GCE (Google Compute Engine). For that you have to setup your own project and use `cloudbuild.yaml`
for building the docker image from the root Dockerfile.

## Features

- `GET /channelHistory/{channelName}` returns the whole dialog (without emojis and links) from the unique channel in though all connected guilds.
**IMPORTANT**: In order to retrieve this dialog, first you need to traverse all the messages with `tl;dr` command in the desired channel. After a
short wait you can call this endpoint and paste the result into [tl;dr openai prompt](https://beta.openai.com/playground/p/default-tldr-summary?model=text-davinci-003)
and get the result.
