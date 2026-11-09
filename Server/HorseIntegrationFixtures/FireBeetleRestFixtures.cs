// SPDX-License-Identifier: GPL-3.0-or-later
using System.Net;
using Server;
using Server.Commands;
using Server.Mobiles;

namespace BritanniaReborn.HorseIntegrationFixtures;

public static class FireBeetleRestFixtures
{
    public static void Configure()
    {
        if (ServerConfiguration.GetOrUpdateSetting("britanniaReborn.isolatedHorseTests", false)
            && ServerConfiguration.GetOrUpdateSetting("britanniaReborn.isolatedFireBeetleRestTests", false))
        {
            CommandSystem.Register("FireBeetleRestFixture", AccessLevel.Player, Execute);
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

        if (args.Length != 2 || World.FindMobile((Serial)(uint)args.GetInt32(0)) is not FireBeetle subject
            || subject.Deleted || !subject.Alive || subject.Body.BodyID != 169
            || subject.ControlMaster != owner || subject.Rider != null || subject.Map != owner.Map
            || !owner.InRange(subject, 2))
        {
            owner.SendMessage("UCEQUINE|blocked|fire-beetle-rest-subject");
            return;
        }

        var action = args.GetInt32(1);
        var frames = action switch { 3 => 5, 4 => 3, 11 => 6, _ => 0 };
        if (frames == 0)
        {
            owner.SendMessage("UCEQUINE|blocked|fire-beetle-rest-group");
            return;
        }

        subject.Animate(action, frames, 1, true, false, 0);
        owner.SendMessage($"UCEQUINE|fire-beetle-rest|{subject.Serial.Value}|{action}");
    }
}
