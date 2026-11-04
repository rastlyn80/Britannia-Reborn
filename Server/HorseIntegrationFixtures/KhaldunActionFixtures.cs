// SPDX-License-Identifier: GPL-3.0-or-later
using System.Net;
using Server;
using Server.Commands;
using Server.Mobiles;

namespace BritanniaReborn.HorseIntegrationFixtures;

public static class KhaldunActionFixtures
{
    public static void Configure()
    {
        if (ServerConfiguration.GetOrUpdateSetting("britanniaReborn.isolatedHorseTests", false)
            && ServerConfiguration.GetOrUpdateSetting("britanniaReborn.isolatedKhaldunActionTests", false))
        {
            CommandSystem.Register("KhaldunActionFixture", AccessLevel.Player, SendAction);
        }
    }

    private static void SendAction(CommandEventArgs args)
    {
        if (args.Mobile is not PlayerMobile player || player.NetState is not { } state
            || !IPAddress.IsLoopback(state.Address)
            || player.Account?.Username?.StartsWith("brhorse-test-", StringComparison.Ordinal) != true)
        {
            return;
        }

        if (args.Length != 3 || World.FindMobile((Serial)(uint)args.GetInt32(0)) is not BaseCreature creature
            || !creature.Frozen || !creature.Alive || creature.Map != player.Map
            || !creature.InRange(player.Location, 18) || !player.CanSee(creature)
            || !(creature is SpectralArmour && creature.Body.BodyID == 637
                || creature is RestlessSoul && creature.Body.BodyID == 970))
        {
            player.SendMessage("UCCREATURE|blocked|khaldun-subject");
            return;
        }

        var action = args.GetInt32(1);
        var frames = args.GetInt32(2);
        if (action is < 0 or > 34 || frames is < 1 or > 20)
        {
            player.SendMessage("UCCREATURE|blocked|khaldun-action");
            return;
        }

        creature.Animate(action, frames, 1, true, false, 0);
        player.SendMessage($"UCCREATURE|khaldun-action|{creature.Serial.Value}|{action}|{frames}");
    }
}
