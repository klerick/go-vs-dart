FROM dart:3.11 AS builder

WORKDIR /app
COPY pubspec.yaml ./
RUN dart pub get
COPY bin/ bin/
RUN dart compile exe bin/server.dart -o server

FROM scratch
COPY --from=builder /runtime/ /
COPY --from=builder /app/server /server
ENTRYPOINT ["/server"]
