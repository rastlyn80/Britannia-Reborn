// SPDX-License-Identifier: GPL-3.0-or-later
using System.Net;
using Server;
using Server.Commands;
using Server.Mobiles;

namespace BritanniaReborn.HorseIntegrationFixtures;

// Deactivate() is sector-sensitive; an active-sector fixture needs Timer.Stop().
public static class FixtureAIControls
{
    internal static void Stop(BaseCreature creature) => creature.AIObject?.AITimer.Stop();
    internal static bool Stopped(BaseCreature creature) =>
        creature.Deleted || creature.AIObject is { } ai && !ai.AITimer.Running;

    public static void Configure()
    {
        if (ServerConfiguration.GetOrUpdateSetting("britanniaReborn.isolatedHorseTests", false)
            && (ServerConfiguration.GetOrUpdateSetting("britanniaReborn.isolatedMageTests", false)
                || ServerConfiguration.GetOrUpdateSetting("britanniaReborn.isolatedJukaTests", false)))
        {
            CommandSystem.Register("CreaturePauseAI", AccessLevel.Player, Pause);
        }
    }

    private static void Pause(CommandEventArgs args)
    {
        if (args.Mobile is not PlayerMobile player || player.NetState is not { } state
            || !IPAddress.IsLoopback(state.Address)
            || player.Account?.Username?.StartsWith("brhorse-test-", StringComparison.Ordinal) != true
            || World.FindMobile((Serial)(uint)args.GetInt32(0)) is not BaseCreature creature)
        {
            return;
        }
        var allowed = creature is EvilMage or EvilMageLord
            && ServerConfiguration.GetOrUpdateSetting("britanniaReborn.isolatedMageTests", false)
            || creature is JukaMage or JukaWarrior
            && ServerConfiguration.GetOrUpdateSetting("britanniaReborn.isolatedJukaTests", false);
        if (!allowed || creature.Map != player.Map || !creature.InRange(player.Location, 18))
        {
            return;
        }
        Stop(creature);
        player.SendMessage($"UCCREATURE|paused|{creature.Serial.Value}|{(Stopped(creature) ? 1 : 0)}");
    }
}
