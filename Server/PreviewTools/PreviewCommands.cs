// SPDX-License-Identifier: GPL-3.0-or-later
using System.Net;
using Server;
using Server.Commands;
using Server.Items;
using Server.Network;
using Server.Misc;
using System.Reflection;

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
        CommandSystem.Register("PreviewEnvironment", AccessLevel.Player, EnvironmentSnapshot);
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

    // Read-only snapshot of the pinned upstream weather scheduler. Native weather
    // packets have no initial snapshot or region-exit clear; this fills that gap
    // for the requesting loopback client, without changing weather or the world.
    private static void EnvironmentSnapshot(CommandEventArgs args)
    {
        if (!Allowed(args))
        {
            return;
        }
        var mobile = args.Mobile;
        Clock.GetTime(mobile.Map, mobile.X, mobile.Y, out var hours, out int minutes);
        mobile.SendMessage($"UCENV1|{hours}|{minutes}|{Clock.SecondsPerUOMinute}");
        mobile.CheckLightLevels(true);
        byte type = 0xFF, density = 0, temperature = 15;
        var flags = BindingFlags.Instance | BindingFlags.NonPublic;
        var activeField = typeof(Weather).GetField("m_Active", flags);
        var stageField = typeof(Weather).GetField("m_Stage", flags);
        var extremeField = typeof(Weather).GetField("m_ExtremeTemperature", flags);
        // Fail explicitly if upgrading the pinned dependency changes its internals.
        if (activeField == null || stageField == null || extremeField == null)
        {
            mobile.SendMessage("Environment weather snapshot unavailable: upstream weather layout changed.");
            return;
        }
        var weatherList = Weather.GetWeatherList(mobile.Map);
        if (weatherList != null)
        {
            foreach (var weather in weatherList)
            {
                if (!(bool)activeField.GetValue(weather)!)
                {
                    continue;
                }
                var contains = weather.Area.Length == 0;
                foreach (var area in weather.Area)
                {
                    contains |= area.Contains(mobile.Location);
                }
                if (!contains)
                {
                    continue;
                }
                var stage = ((int)stageField.GetValue(weather)! + 29) % 30;
                var amount = stage < 15 ? stage * 5 : Math.Clamp(150 - stage * 5, 10, 70);
                if (amount <= density)
                {
                    continue;
                }
                var temp = weather.Temperature * ((bool)extremeField.GetValue(weather)! ? -1 : 1);
                density = (byte)amount;
                temperature = unchecked((byte)temp);
                type = (byte)(temp > 0 ? 0 : 2);
            }
        }
        mobile.NetState.SendWeather(type, density, temperature);
    }

    private static void Help(CommandEventArgs args)
    {
        if (!Allowed(args)) return;
        args.Mobile.SendMessage("[PreviewHome: return to Britain. [PreviewWhere: position. [PreviewCommands: this list.");
        args.Mobile.SendMessage("Native staff commands include [Where and [Go x y z; ModernUO checks your access level.");
    }
}
