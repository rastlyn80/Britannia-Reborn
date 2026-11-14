// SPDX-License-Identifier: GPL-3.0-or-later
using ModernUO.Serialization;
using Server.Commands;
using Server.Engines.MLQuests;
using Server.Engines.MLQuests.Objectives;
using Server.Engines.MLQuests.Rewards;
using Server.Engines.Spawners;
using Server.Items;

namespace Server.Mobiles;

[QuesterName("The Frightened Dryad (Blighted Grove)")]
[SerializationGenerator(0)]
public sealed partial class FrightenedDryad : BaseCreature
{
    public static readonly Point3D GroveHome = new(6500, 875, 0);

    [Constructible]
    public FrightenedDryad() : base(AIType.AI_Vendor, FightMode.None, 2)
    {
        Female = true;
        Body = 266;
        CantWalk = true;
        InitStats(100, 100, 25);
    }

    public override string DefaultName => "The Frightened Dryad";
    public override bool IsInvulnerable => true;

    public override void OnDoubleClick(Mobile from)
    {
        if (from.Map != Map || !from.InRange(this, 2) || !from.InLOS(this))
        {
            from.SendLocalizedMessage(1019045);
            return;
        }

        base.OnDoubleClick(from);
    }
}

public sealed class BoundToTheLand : MLQuest
{
    public BoundToTheLand()
    {
        Activated = true;
        Title = 1074433;
        Description = 1074434;
        RefusalMessage = 1074435;
        InProgressMessage = 1074436;
        CompletionMessage = 1074437;
        var grove = new QuestArea("Blighted Grove", "Blighted Grove");
        Objectives.Add(new KillObjective(12, [typeof(InsaneDryad)], "Insane Dryads", grove));
        Objectives.Add(new KillObjective(1, [typeof(Saliva)], "Saliva", grove));
        Rewards.Add(new ItemReward(1074345, typeof(DryadsBlessing)));
    }
}

public static class BlightedGroveQuests
{
    public static void Configure() => MLQuestSystem.Register(new BoundToTheLand(), typeof(FrightenedDryad));

    public static void Initialize() =>
        CommandSystem.Register("PlaceFrightenedDryad", AccessLevel.Administrator, PlaceDryad);

    private static void PlaceDryad(CommandEventArgs args)
    {
        var home = FrightenedDryad.GroveHome;
        var map = args.Mobile.Map;
        if (map != Map.Trammel && map != Map.Felucca || !args.Mobile.InRange(home, 10)
            || !Region.Find(home, map).IsPartOf("Blighted Grove")
            || !map.CanFit(home, 16, checkMobiles: false))
        {
            args.Mobile.SendMessage("Stand near the Dryad's home inside Blighted Grove.");
            return;
        }

        foreach (var existing in map.GetItemsAt<BaseSpawner>(home))
        {
            if (existing.Entries.Any(entry => entry.SpawnedName.Equals(nameof(FrightenedDryad), StringComparison.OrdinalIgnoreCase)))
            {
                args.Mobile.SendMessage("The Frightened Dryad is already in place.");
                return;
            }
        }
        foreach (var existing in map.GetMobilesInRange<FrightenedDryad>(home, 8))
        {
            args.Mobile.SendMessage("The Frightened Dryad is already in place.");
            return;
        }

        var spawner = new Spawner(1, TimeSpan.FromMinutes(5), TimeSpan.FromMinutes(10),
            spawnedNames: nameof(FrightenedDryad))
        {
            HomeRange = 0,
            WalkingRange = 0
        };
        spawner.MoveToWorld(home, map);
        spawner.Spawn(0, out _);
        args.Mobile.SendMessage("The Frightened Dryad is in place.");
    }
}
