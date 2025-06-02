const std = @import("std");
const mem = std.mem;
const unicode = std.unicode;
const win32 = @import("win32");
const credentials = win32.security.credentials;

pub fn writeCredential(allocator: mem.Allocator, username: []const u8, password: []const u8) !void {
    const target_utf16 = try unicode.utf8ToUtf16LeAllocZ(allocator, "TERMSRV/localhost");
    defer allocator.free(target_utf16);

    const username_utf16 = try unicode.utf8ToUtf16LeAllocZ(allocator, username);
    defer allocator.free(username_utf16);

    // `CredentialBlob` field does not need to be null-terminated.
    const password_utf16 = try unicode.utf8ToUtf16LeAlloc(allocator, password);
    defer allocator.free(password_utf16);

    var credential = mem.zeroInit(credentials.CREDENTIALW, .{ .Type = credentials.CRED_TYPE_DOMAIN_PASSWORD });
    credential.TargetName = target_utf16.ptr;
    credential.CredentialBlobSize = @intCast(password_utf16.len * @sizeOf(u16));
    credential.CredentialBlob = @ptrCast(password_utf16.ptr);
    credential.Persist = credentials.CRED_PERSIST_SESSION;
    credential.UserName = username_utf16.ptr;

    _ = credentials.CredWriteW(&credential, 0);
}
