// SPDX-License-Identifier: GPL-3.0-or-later
using System.Net;
using Server;
using Server.Commands;
using Server.Mobiles;

namespace BritanniaReborn.HorseIntegrationFixtures;

public static class DesertOstardActionFixtures
{
    public static void Configure()
    {
        if (ServerConfiguration.GetOrUpdateSetting("britanniaReborn.isolatedHorseTests", false)
            && ServerConfiguration.GetOrUpdateSetting("britanniaReborn.isolatedDesertOstardActions", false))
        {
            CommandSystem.Register("DesertOstardActionFixture", AccessLevel.Player, SendAction);
        }
    }

    private static void SendAction(CommandEventArgs args)
    {
        if (args.Mobile is not PlayerMobile owner || owner.NetState is not { } state
            || !IPAddress.IsLoopback(state.Address)
            || owner.Account?.Username?.StartsWith("brhorse-test-", StringComparison.Ordinal) != true)
        {
            return;
        }

        if (args.Length != 2 || World.FindMobile((Serial)(uint)args.GetInt32(0)) is not DesertOstard subject
            || !subject.Alive || subject.Body.BodyID != 210 || subject.Rider != null
            || subject.ControlMaster != owner || subject.Map != owner.Map
            || !subject.InRange(owner.Location, 18) || !owner.CanSee(subject))
        {
            owner.SendMessage("UCEQUINE|ostard-action-blocked|subject");
            return;
        }

        var action = args.GetInt32(1);
        if (action is not (4 or 6 or 9 or 10 or 12))
        {
            owner.SendMessage("UCEQUINE|ostard-action-blocked|group");
            return;
        }

        subject.Animate(action, 6, 1, true, false, 0);
        owner.SendMessage($"UCEQUINE|ostard-action|{subject.Serial.Value}|{action}");
    }
}
