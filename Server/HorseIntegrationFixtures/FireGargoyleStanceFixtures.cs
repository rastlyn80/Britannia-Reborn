// SPDX-License-Identifier: GPL-3.0-or-later
using System.Net;
using Server;
using Server.Commands;
using Server.Mobiles;

namespace BritanniaReborn.HorseIntegrationFixtures;

public static class FireGargoyleStanceFixtures
{
    public static void Configure()
    {
        if (ServerConfiguration.GetOrUpdateSetting("britanniaReborn.isolatedHorseTests", false)
            && ServerConfiguration.GetOrUpdateSetting("britanniaReborn.isolatedFireGargoyleStanceTests", false))
        {
            CommandSystem.Register("FireGargoyleStanceFixture", AccessLevel.Player, Execute);
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

        if (args.Length != 2 || World.FindMobile((Serial)(uint)args.GetInt32(0)) is not FireGargoyle subject
            || subject.Deleted || !subject.Alive || !subject.Frozen || subject.Map != owner.Map
            || !owner.InRange(subject, 2) || EquineFixtures.BovineArena is not { } arena || !owner.InRange(arena, 2))
        {
            owner.SendMessage("UCCREATURE|blocked|fire-stance-subject");
            return;
        }

        FixtureAIControls.Stop(subject);
        if (!FixtureAIControls.Stopped(subject))
        {
            owner.SendMessage("UCCREATURE|blocked|fire-stance-ai");
            return;
        }
        subject.Warmode = args.GetInt32(1) != 0;
        subject.ProcessDelta();
        owner.SendMessage($"UCCREATURE|fire-stance|{(subject.Warmode ? 1 : 0)}");
    }
}
