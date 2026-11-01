// SPDX-License-Identifier: GPL-3.0-or-later
using System.Text.Json;
using Server;
using Server.Accounting;
using Server.Misc;

namespace UltimaClone.PreviewTools;

// Unattended first start (scripts/package-friends.ps1): ModernUO asks for its
// owner account on the console, which a hidden server cannot answer. When the
// world has loaded with no accounts and Data/ultimaclone-owner.json exists
// ({"username","password"}), this creates that Owner account and deletes the
// file, before ModernUO's own prompt runs (AccountPrompt.Initialize). Without
// the file nothing happens.
public static class OwnerBootstrap
{
    public static void Configure() => EventSink.WorldLoad += Create;

    private static void Create()
    {
        var path = Path.Combine(Core.BaseDirectory, "Data/ultimaclone-owner.json");
        if (Accounts.Count > 0 || !File.Exists(path)) return;
        using (var document = JsonDocument.Parse(File.ReadAllText(path)))
        {
            var username = document.RootElement.GetProperty("username").GetString() ?? "";
            var password = document.RootElement.GetProperty("password").GetString() ?? "";
            if (username.Length > 0 && password.Length > 0)
            {
                var account = new Account(username, password) { AccessLevel = AccessLevel.Owner };
                ServerAccess.AddProtectedAccount(account, true);
                Console.WriteLine($"UltimaClone: owner account {username} created for an unattended first start.");
            }
        }
        File.Delete(path);
    }
}
