// SPDX-License-Identifier: GPL-3.0-or-later
using System.Net;
using Server;
using Server.Commands;
using Server.Mobiles;

namespace BritanniaReborn.HorseIntegrationFixtures;

public static class RestlessSoulMountFixtures
{
    private sealed record Subject(RestlessSoul Ghost, Horse Horse);
    private static readonly Dictionary<Mobile, Subject> Subjects = [];

    public static void Configure()
    {
        if (ServerConfiguration.GetOrUpdateSetting("britanniaReborn.isolatedHorseTests", false)
            && ServerConfiguration.GetOrUpdateSetting("britanniaReborn.isolatedRestlessSoulMountTests", false))
        {
            CommandSystem.Register("GhostMountFixture", AccessLevel.Player, Execute);
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

        var command = args.GetString(0);
        if (command == "cleanup" && Subjects.Remove(owner, out var finished))
        {
            finished.Horse.Delete();
            owner.SendMessage("UCCREATURE|ghost-mount|cleaned");
            return;
        }

        if (command == "death" && Subjects.TryGetValue(owner, out var dead) && !dead.Ghost.Alive)
        {
            owner.SendMessage($"UCCREATURE|ghost-mount|death|{(dead.Horse.Rider == null ? 1 : 0)}|{(dead.Horse.Deleted ? 1 : 0)}|{(dead.Ghost.FindItemOnLayer(Layer.Mount) == null ? 1 : 0)}");
            return;
        }

        if (args.Length < 2 || World.FindMobile((Serial)(uint)args.GetInt32(1)) is not RestlessSoul ghost
            || !ghost.Frozen || !ghost.Alive || ghost.Body.BodyID != 970 || ghost.Map != owner.Map
            || !ghost.InRange(owner.Location, 18) || !owner.CanSee(ghost))
        {
            owner.SendMessage("UCCREATURE|blocked|ghost-mount-subject");
            return;
        }

        if (!Subjects.TryGetValue(owner, out var subject))
        {
            if (command != "mount" || ghost.Mount != null)
            {
                owner.SendMessage("UCCREATURE|blocked|ghost-mount-state");
                return;
            }
            var horse = new Horse { Frozen = true, Hue = 0x489, Direction = ghost.Direction };
            horse.MoveToWorld(ghost.Location, ghost.Map);
            subject = new Subject(ghost, horse);
            Subjects[owner] = subject;
        }

        if (subject.Ghost != ghost || subject.Horse.Deleted)
        {
            owner.SendMessage("UCCREATURE|blocked|ghost-mount-state");
            return;
        }

        switch (command)
        {
            case "mount":
                subject.Horse.Direction = ghost.Direction;
                subject.Horse.Rider = ghost;
                if (ghost.FindItemOnLayer(Layer.Mount) is { } item)
                {
                    owner.SendMessage($"UCCREATURE|ghost-mount|worn|{subject.Horse.Serial.Value}|{subject.Horse.Body.BodyID}|{item.Serial.Value}|{item.ItemID}|{item.Hue}");
                    return;
                }
                break;
            case "dismount" when subject.Horse.Rider == ghost:
                subject.Horse.Rider = null;
                owner.SendMessage($"UCCREATURE|ghost-mount|loose|{subject.Horse.Serial.Value}");
                return;
            case "dye" when args.Length == 3 && subject.Horse.Rider == ghost:
                subject.Horse.Hue = args.GetInt32(2) & 0xFFFF;
                owner.SendMessage($"UCCREATURE|ghost-mount|dyed|{subject.Horse.Hue}");
                return;
        }
        owner.SendMessage("UCCREATURE|blocked|ghost-mount-command");
    }
}
