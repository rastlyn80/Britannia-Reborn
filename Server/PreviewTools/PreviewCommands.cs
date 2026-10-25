// SPDX-License-Identifier: GPL-3.0-or-later
using System.Net;
using Server;
using Server.Commands;

namespace UltimaClone.PreviewTools;

// Development recovery is deliberately separate from staff privilege. It can
// only return the caller to one fixed safe point on this loopback preview shard.
public static class PreviewCommands
{
    public static void Configure()
    {
        if (!ServerConfiguration.GetOrUpdateSetting("ultimaClone.previewTools", false)) return;
        CommandSystem.Register("PreviewHome", AccessLevel.Player, Home);
        CommandSystem.Register("PreviewWhere", AccessLevel.Player, Where);
        CommandSystem.Register("PreviewCommands", AccessLevel.Player, Help);
    }

    private static bool Allowed(CommandEventArgs args)
    {
        if (args.Mobile.NetState is { } state && IPAddress.IsLoopback(state.Address)) return true;
        args.Mobile.SendMessage("Preview tools are available only on the local development connection.");
        return false;
    }

    private static void Home(CommandEventArgs args)
    {
        if (!Allowed(args)) return;
        args.Mobile.Combatant = null;
        args.Mobile.MoveToWorld(new Point3D(1602, 1591, 20), Map.Trammel);
        args.Mobile.SendMessage("Returned to the Britain preview start (1602, 1591, 20), Trammel.");
    }

    private static void Where(CommandEventArgs args)
    {
        if (!Allowed(args)) return;
        var mobile = args.Mobile;
        mobile.SendMessage($"Position: {mobile.X}, {mobile.Y}, {mobile.Z} / {mobile.Map}. Access: {mobile.AccessLevel}.");
    }

    private static void Help(CommandEventArgs args)
    {
        if (!Allowed(args)) return;
        args.Mobile.SendMessage("[PreviewHome: return to Britain. [PreviewWhere: position. [PreviewCommands: this list.");
        args.Mobile.SendMessage("Native staff commands include [Where and [Go x y z; ModernUO checks your access level.");
    }
}
