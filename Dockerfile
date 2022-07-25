FROM dart:stable AS builder

WORKDIR /app
COPY pubspec.* ./
RUN dart pub get

COPY . .
RUN mkdir build
RUN dart pub get --offline
RUN dart pub run build_runner build --delete-conflicting-outputs
RUN dart compile exe lib/server.dart -o build/discord-bot

FROM scratch

ARG DISCORD_TOKEN
ENV TOKEN $DISCORD_TOKEN

COPY --from=builder /app/build /bin
COPY --from=builder /runtime/ /

EXPOSE 80

CMD ["/bin/discord-bot"]
