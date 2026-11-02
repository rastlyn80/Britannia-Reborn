// SPDX-License-Identifier: GPL-3.0-or-later
using System.Net;
using Server;
using Server.Commands;
using Server.Mobiles;

namespace BritanniaReborn.HorseIntegrationFixtures;

// Native helper/damage paths only, in the explicitly enabled disposable world.
public static class SolenBehaviourFixtures
{
    public static void Configure()
    {
        if (ServerConfiguration.GetOrUpdateSetting("britanniaReborn.isolatedHorseTests", false)
            && ServerConfiguration.GetOrUpdateSetting("britanniaReborn.isolatedSolenTests", false))
        {
            CommandSystem.Register("SolenBehaviourFixture", AccessLevel.Player, Execute);
        }
    }

    private static int Flag(bool value) => value ? 1 : 0;

    private static void Execute(CommandEventArgs args)
    {
        if (args.Mobile is not PlayerMobile player || player.NetState is not { } state
            || !IPAddress.IsLoopback(state.Address)
            || player.Account?.Username?.StartsWith("brhorse-test-", StringComparison.Ordinal) != true
            || !AquaticFixtures.Prepare(player, false))
        {
            return;
        }
        var previous = player.SolenFriendship;
        var red = new RedSolenWorker { Frozen = true };
        var black = new BlackSolenWorker { Frozen = true };
        var pet = new Cat { Frozen = true };
        try
        {
            red.MoveToWorld(new Point3D(player.X + 1, player.Y, player.Z), player.Map);
            black.MoveToWorld(new Point3D(player.X + 2, player.Y, player.Z), player.Map);
            pet.MoveToWorld(new Point3D(player.X, player.Y + 1, player.Z), player.Map);
            red.AIObject?.Deactivate();
            black.AIObject?.Deactivate();
            pet.AIObject?.Deactivate();
            if (!pet.SetControlMaster(player))
            {
                player.SendMessage("UCSOLEN|blocked|native-pet-control");
                return;
            }
            foreach (var friendship in new[] { SolenFriendship.None, SolenFriendship.Red, SolenFriendship.Black })
            {
                player.SolenFriendship = friendship;
                player.SendMessage($"UCSOLEN|state|{friendship}|{Flag(SolenHelper.CheckRedFriendship(player))}|{Flag(SolenHelper.CheckBlackFriendship(player))}|{Flag(red.IsEnemy(player))}|{Flag(black.IsEnemy(player))}|{Flag(SolenHelper.CheckRedFriendship(pet))}|{Flag(SolenHelper.CheckBlackFriendship(pet))}|{Flag(red.IsEnemy(pet))}|{Flag(black.IsEnemy(pet))}");
            }
            foreach (var from in new Mobile[] { player, pet })
            {
                player.SolenFriendship = SolenFriendship.Red;
                var before = red.Hits;
                red.Damage(1, from);
                player.SendMessage($"UCSOLEN|damage|red|{(from == player ? "direct" : "pet")}|{Flag(red.Hits < before)}|{Flag(player.SolenFriendship == SolenFriendship.None)}|{Flag(red.IsEnemy(player))}");
                player.SolenFriendship = SolenFriendship.Black;
                before = black.Hits;
                black.Damage(1, from);
                player.SendMessage($"UCSOLEN|damage|black|{(from == player ? "direct" : "pet")}|{Flag(black.Hits < before)}|{Flag(player.SolenFriendship == SolenFriendship.None)}|{Flag(black.IsEnemy(player))}");
            }
            player.SendMessage($"UCSOLEN|done|{red.Body.BodyID}|{black.Body.BodyID}|{black.Hue}|{Flag(pet.GetMaster() == player)}");
        }
        finally
        {
            player.SolenFriendship = previous;
            pet.Delete();
            red.Delete();
            black.Delete();
        }
    }
}
