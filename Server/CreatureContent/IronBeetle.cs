// SPDX-License-Identifier: GPL-3.0-or-later
using ModernUO.Serialization;
using Server.Engines.Harvest;
using Server.Items;

namespace Server.Mobiles;

[SerializationGenerator(0)]
public sealed partial class IronBeetle : BaseCreature
{
    private static readonly TimeSpan _miningInterval = TimeSpan.FromSeconds(5);
    private DateTime _nextOreMeal;
    private Timer? _mining;

    [Constructible]
    public IronBeetle() : base(AIType.AI_Melee, FightMode.Closest, 10, 1)
    {
        Body = 714;
        BaseSoundID = 397;
        SetStr(816, 883);
        SetDex(68, 73);
        SetInt(40, 49);
        SetHits(762, 830);
        SetDamage(15, 20);
        SetDamageType(ResistanceType.Physical, 100);
        SetResistance(ResistanceType.Physical, 55, 60);
        SetResistance(ResistanceType.Fire, 20, 30);
        SetResistance(ResistanceType.Cold, 20, 30);
        SetResistance(ResistanceType.Poison, 30, 40);
        SetResistance(ResistanceType.Energy, 45, 55);
        SetSkill(SkillName.Anatomy, 80.1, 85.0);
        SetSkill(SkillName.MagicResist, 125.1, 130.0);
        SetSkill(SkillName.Tactics, 90.1, 100.0);
        SetSkill(SkillName.Wrestling, 90.1, 110.0);
        SetSkill(SkillName.Mining, 50.1, 70.0);
        Skills.Mining.Cap = 120;
        Fame = 15000;
        Karma = -15000;
        VirtualArmor = 38;
        Tamable = true;
        MinTameSkill = 71.1;
        ControlSlots = 4;
        StartMining();
    }

    public override string DefaultName => "an iron beetle";
    public override string CorpseName => "an iron beetle corpse";
    public override bool SubdueBeforeTame => true;
    public override bool OverrideBondingReqs() => true;
    public override double GetControlChance(Mobile master, bool useBaseSkill = false) => 1.0;
    public override int GetAngerSound() => 0x21D;
    public override int GetIdleSound() => 0x21D;
    public override int GetAttackSound() => 0x162;
    public override int GetHurtSound() => 0x163;
    public override int GetDeathSound() => 0x21D;

    public override void GetSpeeds(out double activeSpeed, out double passiveSpeed)
    {
        activeSpeed = 0.25;
        passiveSpeed = 0.50;
    }

    public override void GenerateLoot()
    {
        AddLoot(LootPack.Meager);
        AddLoot(LootPack.Gems);
    }

    public override void OnDeath(Container corpse)
    {
        base.OnDeath(corpse);
        if (!Controlled && Utility.RandomDouble() < 0.10)
        {
            corpse.DropItem(new UndamagedIronBeetleScale());
        }
    }

    public override void OnThink()
    {
        base.OnThink();
        if (Owners.Count != 0 || !Alive || Deleted || Map == null || Map == Map.Internal || _nextOreMeal > Core.Now)
        {
            return;
        }

        _nextOreMeal = Core.Now + TimeSpan.FromSeconds(3);
        if (Utility.RandomDouble() >= 0.5)
        {
            return;
        }

        BaseOre? nearby = null;
        foreach (var ore in Map.GetItemsInRange<BaseOre>(Location, 1))
        {
            if (Math.Abs(ore.Z - Z) <= 4 && InLOS(ore))
            {
                nearby = ore;
                break;
            }
        }

        if (nearby != null)
        {
            Hue = nearby.Hue;
            nearby.Delete();
        }
    }

    [AfterDeserialization]
    private void StartMining() => _mining = Timer.DelayCall(_miningInterval, _miningInterval, Mine);

    public override void OnDelete()
    {
        _mining?.Stop();
        base.OnDelete();
    }

    private void Mine()
    {
        if (Deleted || !Alive || IsDeadBondedPet || Map == null || Map == Map.Internal || Combatant != null)
        {
            return;
        }

        var map = Map;
        var tile = Location;
        Movement.Movement.Offset(Direction, ref tile);
        var mining = Mining.System;
        var definition = mining.OreAndStone;
        var oreAmount = map == Map.Felucca ? definition.ConsumedPerFeluccaHarvest : definition.ConsumedPerHarvest;
        if (!definition.Validate(map.Tiles.GetLandTile(tile.X, tile.Y).ID & 0x3FFF, isLand: true) ||
            definition.GetBank(map, tile.X, tile.Y) is not { Current: var available, Vein: { } vein } bank ||
            available < oreAmount)
        {
            return;
        }

        var resource = mining.MutateResource(this, null, definition, map, tile, vein, vein.PrimaryResource, definition.Resources[0]);
        var skill = Skills[definition.Skill].Base;
        if (skill < resource.ReqSkill || !CheckSkill(definition.Skill, resource.MinSkill, resource.MaxSkill) ||
            mining.GetResourceType(this, null, definition, map, tile, resource) is not { } type)
        {
            return;
        }

        type = mining.MutateType(type, this, null, definition, map, tile, resource);
        if (type == null || mining.Construct(type, this) is not { } ore)
        {
            return;
        }

        if (ore.Stackable)
        {
            ore.Amount = oreAmount;
        }
        bank.Consume(ore.Amount, this);
        ore.MoveToWorld(tile, map);
        Direction = GetDirectionTo(tile);
        // The stock player mining group 11 is absent from body 714.
        Animate(27, 8, 1, true, false, 0);
        mining.DoHarvestingSound(this, null, definition, null);

        var bonus = definition.GetBonusResource();
        if (bonus?.Type != null && skill >= bonus.ReqSkill)
        {
            mining.Construct(bonus.Type, this)?.MoveToWorld(tile, map);
        }
    }
}
