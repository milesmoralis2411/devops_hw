# Multi-stage Dockerfile
#
# Stage 1 (build): uses the full Go toolchain (~300 MB) to compile a static binary.
# Stage 2 (run):   copies ONLY the compiled binary into a tiny scratch/alpine image.
#
# Result: the final image contains no compiler, no source code, no package
# manager -- just the binary. Image shrinks from ~300 MB to a few MB.

# ---- Stage 1: build ----
FROM golang:1.22-alpine AS build
WORKDIR /src
COPY go.mod ./
COPY main.go ./
# CGO disabled -> fully static binary that runs on a bare image
RUN CGO_ENABLED=0 GOOS=linux go build -o /app/server main.go

# ---- Stage 2: run ----
FROM alpine:3.20
WORKDIR /app
COPY --from=build /app/server ./server
EXPOSE 8080
CMD ["./server"]
