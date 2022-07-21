FROM google/dart
WORKDIR /app
ADD pubspec.* /app/
RUN dart pub get
ADD . /app
RUN dart pub get --offline
CMD []
EXPOSE 443
ENTRYPOINT ["/usr/bin/dart", "bin/server.dart"]
