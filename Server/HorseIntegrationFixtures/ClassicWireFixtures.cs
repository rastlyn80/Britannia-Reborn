// SPDX-License-Identifier: GPL-3.0-or-later
using System.Net;
using Server;
using Server.Commands;
using Server.Mobiles;
using Server.Network;

namespace BritanniaReborn.HorseIntegrationFixtures;

public static class ClassicWireFixtures
{
    private static readonly HashSet<int> Bodies =
    [
        77, 74, 9, 62, 26, 60, 250, 240, 317, 128, 775, 154, 40, 148, 245,
        11, 59, 86, 75, 76, 85, 71, 70, 302, 247, 87, 149, 776, 67, 778,
        805, 152, 780, 789, 784, 772, 267, 304, 46, 756, 252, 271, 280, 43, 768,
        307, 807, 249, 308, 103, 104, 10, 38, 101, 174, 262, 306, 311, 312, 313,
        314, 315, 316, 318, 319, 758,
    ];

    public static void Configure()
    {
        if (ServerConfiguration.GetOrUpdateSetting("britanniaReborn.isolatedHorseTests", false)
            && ServerConfiguration.GetOrUpdateSetting("britanniaReborn.isolatedClassicWireTests", false))
        {
            CommandSystem.Register("ClassicWireFixture", AccessLevel.Player, Execute);
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

        if (args.Length != 3 || World.FindMobile((Serial)(uint)args.GetInt32(0)) is not BaseCreature subject
            || subject.Deleted || !subject.Alive || !subject.Frozen || subject.Map != owner.Map
            || !owner.InRange(subject, 4) || !Bodies.Contains(subject.Body.BodyID))
        {
            owner.SendMessage("UCCREATURE|blocked|classic-wire-subject");
            return;
        }

        var type = args.GetInt32(1);
        var mode = args.GetInt32(2);
        if (type is not (1 or 2 or 11 or 14) || mode is not (0 or 1))
        {
            owner.SendMessage("UCCREATURE|blocked|classic-wire-type");
            return;
        }

        foreach (var client in subject.Map.GetClientsInRange(subject.Location))
        {
            if (client.Mobile.CanSee(subject))
            {
                client.SendNewMobileAnimation(subject.Serial, type, 0, mode);
            }
        }
        owner.SendMessage($"UCCREATURE|classic-wire|{subject.Serial.Value}|{type}|{mode}");
    }
}
