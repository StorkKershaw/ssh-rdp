# ssh-rdp

## Development Environment

### Prerequisites

- Zig 0.14.0
- Inno Setup 6 Command-Line Compiler (ISCC)

### Running in Debug Mode

```shell
$ zig build server   # Build and run the server in debug mode
$ zig build client   # Build and run the client in debug mode
```

### Building for Release

```shell
$ zig build -Doptimize=ReleaseSmall
```
