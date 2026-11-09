// SPDX-License-Identifier: GPL-3.0-or-later
using System.Net;
using Server;
using Server.Commands;
using Server.Items;
using Server.Mobiles;

namespace BritanniaReborn.HorseIntegrationFixtures;

public static class CreatureCombatFlagFixtures
{
    private static readonly Dictionary<Serial, BaseCreature> _creatures = new();

    public static void Configure()
    {
        if (ServerConfiguration.GetOrUpdateSetting("britanniaReborn.isolatedHorseTests", false)
            && ServerConfiguration.GetOrUpdateSetting("britanniaReborn.isolatedCreatureCombatFlagTests", false))
        {
            CommandSystem.Register("CreatureCombatFlagFixture", AccessLevel.Player, Execute);
        }
    }

    private static void Cleanup(PlayerMobile owner)
    {
        if (_creatures.Remove(owner.Serial, out var creature))
        {
            creature.Delete();
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

        switch (args.GetString(0))
        {
            case "arena":
                owner.SendMessage(AquaticFixtures.Prepare(owner, false) ? "UCGFLAG|arena" : "UCGFLAG|blocked|arena");
                return;
            case "cleanup":
                Cleanup(owner);
                owner.SendMessage("UCGFLAG|clean");
                return;
            case "clear-acid":
                ClearArenaAcid(owner);
                return;
            case "prepare":
                Prepare(owner, args.GetInt32(1));
                return;
        }
        if (!_creatures.TryGetValue(owner.Serial, out var creature) || creature.Deleted)
        {
            owner.SendMessage("UCGFLAG|blocked|fixture");
            return;
        }
        FixtureAIControls.Stop(creature);
        if (!FixtureAIControls.Stopped(creature))
        {
            owner.SendMessage("UCGFLAG|blocked|ai");
            return;
        }

        if (args.GetString(0) == "mode")
        {
            creature.Warmode = args.GetInt32(1) != 0;
            creature.ProcessDelta();
            owner.SendMessage($"UCGFLAG|mode|{(creature.Warmode ? 1 : 0)}");
        }
        else if (args.GetString(0) == "step")
        {
            var origin = creature.Location;
            for (var direction = 0; direction < 8 && creature.Location == origin; direction++)
            {
                for (var attempt = 0; attempt < 2 && creature.Location == origin; attempt++)
                {
                    creature.Move((Direction)direction);
                }
            }
            FixtureAIControls.Stop(creature);
            if (creature.Location != origin)
            {
                creature.ProcessDelta();
                owner.SendMessage($"UCGFLAG|step|{creature.X}|{creature.Y}|{creature.Z}");
            }
        }
    }

    private static void ClearArenaAcid(PlayerMobile owner)
    {
        if (EquineFixtures.BovineArena is not { } arena || !owner.InRange(arena, 2))
        {
            owner.SendMessage("UCCREATURE|blocked|acid-arena");
            return;
        }

        // The native Solen death creates real damaging pools. Clear them after
        // the corpse has been checked so the next test subject starts clean.
        var pools = new List<Acid>();
        foreach (var pool in owner.Map.GetItemsInRange<Acid>(arena, 8))
        {
            pools.Add(pool);
        }
        foreach (var pool in pools)
        {
            pool.Delete();
        }
        owner.SendMessage($"UCCREATURE|acid-cleared|{pools.Count}");
    }

    private static void Prepare(PlayerMobile owner, int body)
    {
        Cleanup(owner);
        BaseCreature? creature = body switch
        {
            730 => new Raptor(),
            734 => new Slith(),
            _ => null
        };
        if (creature == null || !AquaticFixtures.Prepare(owner, false))
        {
            creature?.Delete();
            owner.SendMessage("UCGFLAG|blocked|body-or-arena");
            return;
        }
        creature.MoveToWorld(new Point3D(owner.X + 2, owner.Y + 1, owner.Z), owner.Map);
        FixtureAIControls.Stop(creature);
        _creatures[owner.Serial] = creature;
        owner.SendMessage($"UCGFLAG|prepared|{creature.Serial.Value}|{creature.Body.BodyID}");
    }
}
