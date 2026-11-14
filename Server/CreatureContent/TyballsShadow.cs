// SPDX-License-Identifier: GPL-3.0-or-later
using ModernUO.Serialization;
using Server.Commands;
using Server.Engines.Spawners;
using Server.Items;

namespace Server.Mobiles;

[CorpseName("the remains of Tyball's Shadow")]
[SerializationGenerator(0)]
public sealed partial class TyballsShadow : BaseCreature
{
    public static readonly Point3D Shrine = new(1181, 885, 0);
    private static readonly Point3D _gate = new(1187, 1126, -42);
    private static readonly Point3D _gateApproach = new(1187, 1127, -42);
    private static readonly Point3D _arrival = new(1180, 884, 0);
    private static readonly Point3D _exit = new(1180, 885, 0);
    private const int RedGateGraphic = 0x0DDA;

    [Constructible]
    public TyballsShadow() : base(AIType.AI_Mage, FightMode.Closest, 10)
    {
        Body = 400;
        Hue = 0x0455;
        SetStr(400, 450);
        SetDex(210, 250);
        SetInt(310, 330);
        SetHits(2800, 3000);
        SetDamage(20, 25);
        for (var resistance = ResistanceType.Physical; resistance <= ResistanceType.Energy; resistance++)
        {
            SetResistance(resistance, 70);
        }

        SetSkill(SkillName.EvalInt, 100.0);
        SetSkill(SkillName.Magery, 110.0);
        SetSkill(SkillName.MagicResist, 110.0);
        SetSkill(SkillName.Meditation, 100.0);
        SetSkill(SkillName.Tactics, 95.0);
        SetSkill(SkillName.Wrestling, 95.0);
        Fame = 20000;
        Karma = -20000;
        AddItem(new HoodedShroudOfShadows(0x0455) { Movable = false });
    }

    public override string DefaultName => "Tyball's Shadow";
    public override bool AlwaysMurderer => true;

    public override void GenerateLoot()
    {
        AddLoot(LootPack.Rich, 2);
        if (!m_Spawning && Utility.RandomDouble() < .01)
        {
            PackItem(new ShroudOfTheCondemned());
        }
    }

    public override void OnDeath(Container corpse)
    {
        if (!Summoned && !NoKillAwards)
        {
            var killer = LastKiller is BaseCreature creature ? creature.GetDamageMaster(this) : LastKiller;
            if (killer is PlayerMobile { Map: var map, Backpack: { } pack } player &&
                map == Map && player.InRange(this, 18) &&
                !UnderworldKey.HasFragment(pack, UnderworldFragment.Yellow) &&
                !UnderworldKey.HasFragment(pack, UnderworldFragment.Complete))
            {
                var fragment = new UnderworldKey(UnderworldFragment.Yellow);
                if (pack.TryDropItem(player, fragment, true))
                {
                    player.SendLocalizedMessage(1113701);
                }
                else
                {
                    corpse.DropItem(fragment);
                }
            }
        }

        base.OnDeath(corpse);
    }

    public static void Initialize()
    {
        CommandSystem.Register("PlaceTyballsShadow", AccessLevel.Administrator, Place);
        CommandSystem.Register("PlaceTyballShrineGates", AccessLevel.Administrator, PlaceGates);
    }

    private static void PlaceGates(CommandEventArgs args)
    {
        var actor = args.Mobile;
        var map = Map.TerMur;
        if (actor.Map != map || !actor.InRange(_gate, 3) || Math.Abs(actor.Z - _gate.Z) > 6)
        {
            actor.SendMessage("Stand by the red moongate in the ankh-shaped chamber.");
            return;
        }

        if (!FindGate(map, _gate, _arrival, out var entrance) || !FindGate(map, _exit, _gateApproach, out var exit))
        {
            actor.SendMessage("An existing teleporter at the shrine has a different destination or is inactive.");
            return;
        }

        if (entrance == null)
        {
            new Teleporter(_arrival, map).MoveToWorld(_gate, map);
        }

        if (exit == null)
        {
            new Teleporter(_gateApproach, map).MoveToWorld(_exit, map);
        }

        foreach (var item in map.GetItemsAt<Item>(_gate))
        {
            if (item.Z == _gate.Z && item.ItemID == RedGateGraphic)
            {
                actor.SendMessage("The red shrine gate is already visible.");
                return;
            }
        }

        new Static(RedGateGraphic).MoveToWorld(_gate, map);
        actor.SendMessage("The red shrine gate and return route are in place.");
    }

    private static bool FindGate(Map map, Point3D location, Point3D destination, out Teleporter? result)
    {
        result = null;
        foreach (var gate in map.GetItemsAt<Teleporter>(location))
        {
            if (Math.Abs(gate.Z - location.Z) > 2)
            {
                continue;
            }

            if (result != null || gate.GetType() != typeof(Teleporter) || !gate.Active ||
                gate.PointDest != destination || (gate.MapDest != map && gate.MapDest != null))
            {
                return false;
            }

            result = gate;
        }

        return true;
    }

    private static void Place(CommandEventArgs args)
    {
        var actor = args.Mobile;
        var map = Map.TerMur;
        if (actor.Map != map || !actor.InRange(Shrine, 3) || !map.CanFit(Shrine, 16, checkMobiles: false))
        {
            actor.SendMessage("Stand on the inner shrine platform in the Underworld.");
            return;
        }

        foreach (var existing in map.GetItemsInRange<Spawner>(Shrine, 8))
        {
            if (existing.Location == Shrine)
            {
                actor.SendMessage("A spawner already occupies the shrine platform.");
                return;
            }
        }

        var delay = TimeSpan.FromSeconds(150);
        var spawner = new Spawner(nameof(TyballsShadow)) { Count = 1, MinDelay = delay, MaxDelay = delay,
            HomeRange = 0, WalkingRange = 1 };
        spawner.MoveToWorld(Shrine, map);
        spawner.Start();
        actor.SendMessage("Tyball's Shadow spawn is in place.");
    }
}
