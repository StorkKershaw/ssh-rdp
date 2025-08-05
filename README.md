# ssh-rdp

## How to Use

1. [Download the latest installer](https://github.com/StorkKershaw/ssh-rdp/releases/latest).
2. Run the installer and follow instructions.
3. Update your SSH config file with the following settings to enable RDP forwarding:
    ```diff
    Host <your-host>
        HostName <remote-address>
        User <your-username>
    +    LocalForward localhost:10000 localhost:3389
    +    PermitLocalCommand yes
    +    LocalCommand echo --user <your-username> --password <your-logon-password> --address localhost:10000 > \\.\pipe\ssh-rdp-%n
    ```
    - Replace `<your-host>`, `<remote-address>`, and `<your-username>` with your actual SSH host, remote address, and username.
    - Replace `<your-logon-password>` with your Windows logon password.
      You may omit the `--password` argument to be prompted when connecting.
4. Start the connection by running:
    ```shell
    $ ssh-rdp <your-host>
    ```

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

## License

### Application

- This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

### Icon

- <a href="https://www.flaticon.com/free-icons/remote-desktop" title="remote-desktop icons">Remote-desktop icons created by Ida Desi Mariana - Flaticon</a>
