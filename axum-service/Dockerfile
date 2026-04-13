FROM rust:1-alpine AS builder

RUN apk add --no-cache musl-dev build-base

WORKDIR /app
ENV RUSTFLAGS="-C target-cpu=native"

COPY Cargo.toml Cargo.lock ./
RUN mkdir src && echo "fn main() {}" > src/main.rs && cargo build --release && rm -rf src

COPY src/ src/
RUN touch src/main.rs && cargo build --release

FROM scratch
COPY --from=builder /app/target/release/axum-service /server
ENTRYPOINT ["/server"]
