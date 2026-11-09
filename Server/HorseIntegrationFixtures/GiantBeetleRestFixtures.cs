// SPDX-License-Identifier: GPL-3.0-or-later
using System.Net;
using Server;
using Server.Commands;
using Server.Mobiles;

namespace BritanniaReborn.HorseIntegrationFixtures;

public static class GiantBeetleRestFixtures
{
    public static void Configure()
    {
        if (ServerConfiguration.GetOrUpdateSetting("britanniaReborn.isolatedHorseTests", false)
            && ServerConfiguration.GetOrUpdateSetting("britanniaReborn.isolatedGiantBeetleRestTests", false))
        {
            CommandSystem.Register("GiantBeetleRestFixture", AccessLevel.Player, Execute);
        }
    }

    private static void Execute(CommandEventArgs args)
    {
        if (args.Mobile is not PlayerMobile owner || owner.NetState is not { } state
            || !IPAddress.IsLoopback(state.Address)
            || owner.Account?.Username?.StartsWith("brhorse-test-", StringComparison.Ordinal) != true)
        {
            return;
        }

        if (args.Length != 1 || World.FindMobile((Serial)(uint)args.GetInt32(0)) is not Beetle subject
            || subject.Deleted || !subject.Alive || subject.Body.BodyID != 791
            || subject.ControlMaster != owner || subject.Rider != null || subject.Map != owner.Map
            || !owner.InRange(subject, 2))
        {
            owner.SendMessage("UCEQUINE|blocked|beetle-rest-subject");
            return;
        }

        subject.Animate(11, 6, 1, true, false, 0);
        owner.SendMessage($"UCEQUINE|beetle-rest|{subject.Serial.Value}");
    }
}
