// SPDX-License-Identifier: GPL-3.0-or-later
using ModernUO.Serialization;
using Server.Engines.BuffIcons;
using Server.Items;
using Server.Spells;

namespace Server.Mobiles;

[SerializationGenerator(0)]
public sealed partial class LadyMelisande : BaseCreature
{
    private static readonly Point3D[] GroveSatyrs =
    [
        new(6485, 945, 19), new(6486, 948, 22), new(6487, 945, 17), new(6488, 947, 23)
    ];

    [SerializableField(0)]
    private List<BaseCreature> _satyrs = [];

    [SerializableField(1)]
    private bool _calledReinforcements;

    private long _nextVitality;
    private long _nextTaunt;
    private long _nextNausea;

    internal BlightedGroveBasket? Basket { get; set; }

    [Constructible]
    public LadyMelisande() : base(AIType.AI_Mage, FightMode.Closest, 10, 1)
    {
        Body = 258;
        Female = true;
        BaseSoundID = 451;
        SetStr(400, 1000);
        SetDex(300, 400);
        SetInt(1500, 1700);
        SetHits(100000);
        SetDamage(11, 18);
        SetDamageType(ResistanceType.Physical, 50);
        SetDamageType(ResistanceType.Energy, 50);
        SetResistance(ResistanceType.Physical, 40, 60);
        SetResistance(ResistanceType.Fire, 40, 50);
        SetResistance(ResistanceType.Cold, 55, 65);
        SetResistance(ResistanceType.Poison, 70, 75);
        SetResistance(ResistanceType.Energy, 70, 80);
        SetSkill(SkillName.Wrestling, 100, 105);
        SetSkill(SkillName.Tactics, 100, 105);
        SetSkill(SkillName.MagicResist, 120);
        SetSkill(SkillName.Magery, 120);
        SetSkill(SkillName.EvalInt, 120);
        SetSkill(SkillName.Meditation, 120);
        SetSkill(SkillName.Necromancy, 120);
        SetSkill(SkillName.SpiritSpeak, 120);
        Fame = 25000;
        Karma = -25000;
        VirtualArmor = 50;
        for (var i = 0; i < 8; i++)
        {
            PackItem(Utility.Random(6) switch
            {
                0 => new Blight(),
                1 => new Scourge(),
                2 => new Taint(),
                3 => new Putrefication(),
                4 => new Corruption(),
                _ => new Muculent()
            });
        }
        var talismans = Utility.Random(5);
        for (var i = 0; i < talismans; i++)
        {
            PackItem(new RandomTalisman());
        }
        if (Utility.RandomBool())
        {
            PackItem(Loot.RandomScroll(0, Loot.ArcanistScrollTypes.Length - 1, SpellbookType.Arcanist));
        }
    }

    public override string DefaultName => "Lady Melisande";
    public override string CorpseName => "a lady melisande corpse";
    public override int TreasureMapLevel => 5;
    public override Poison PoisonImmune => Poison.Lethal;
    public override bool GivesMLMinorArtifact => true;

    public override void GetSpeeds(out double activeSpeed, out double passiveSpeed)
    {
        activeSpeed = 0.2;
        passiveSpeed = 0.4;
    }

    public override void OnThink()
    {
        base.OnThink();
        if (Combatant is not Mobile target || !CanBeHarmful(target) || !InLOS(target))
        {
            return;
        }

        var now = Core.TickCount;
        if (now >= _nextVitality && Hits <= HitsMax / 10 && Hits >= HitsMax / 40)
        {
            _nextVitality = now + Utility.RandomMinMax(15000, 60000);
            Hits += target.Hits / (target.Player ? 2 : 6);
            FixedParticles(0x376A, 9, 32, 5005, EffectLayer.Waist);
            PlaySound(0x1F2);
            Say(1075117);
            Say(1075120);
        }
        if (now >= _nextTaunt && Hits > HitsMax / 2)
        {
            _nextTaunt = now + Utility.RandomMinMax(2000, 5000);
            Say(Utility.RandomMinMax(1075102, 1075115));
        }
        if (now >= _nextNausea && Mana >= 100 && InRange(target, 4) && !BardPacified)
        {
            CastNausea(now);
        }
        if (!_calledReinforcements && Hits < HitsMax / 2 && Utility.RandomDouble() < 0.05)
        {
            CallReinforcements(target);
        }
    }

    private void CastNausea(long now)
    {
        Mana -= 100;
        _nextNausea = now + Utility.RandomMinMax(40000, 70000);
        foreach (var defender in GetMobilesInRange<Mobile>(4))
        {
            if (defender == this || !defender.Alive || defender.IsDeadBondedPet || !InLOS(defender)
                || _satyrs.Contains(defender) || !CanBeHarmful(defender, false)
                || defender != Combatant && !SpellHelper.ValidIndirectTarget(this, defender))
            {
                continue;
            }
            defender.Animate(32, 5, 1, true, false, 0);
            defender.SendLocalizedMessage(1072068);
            if (defender is PlayerMobile player)
            {
                player.AddBuff(new BuffInfo(BuffIcon.AuraOfNausea, 1153792, 1153819, TimeSpan.FromSeconds(30),
                    "60\t60\t60\t5"));
            }
        }
    }

    private void CallReinforcements(Mobile target)
    {
        var spawned = 0;
        foreach (var fighter in Basket?.Fighters ?? [target])
        {
            if (spawned == 4)
            {
                break;
            }
            if (fighter.Map != Map || !fighter.Alive || !CanBeHarmful(fighter, false))
            {
                continue;
            }
            for (var attempt = 0; attempt < 12; attempt++)
            {
                var point = new Point3D(fighter.X + Utility.RandomMinMax(-2, 2),
                    fighter.Y + Utility.RandomMinMax(-2, 2), fighter.Z);
                if (!Map.CanSpawnMobile(point) || !Region.IsPartOf("Blighted Grove"))
                {
                    continue;
                }
                var satyr = new EnslavedSatyr { Home = point, RangeHome = 4, FightMode = FightMode.Closest };
                satyr.MoveToWorld(point, Map);
                satyr.Combatant = fighter;
                _satyrs.Add(satyr);
                fighter.SendLocalizedMessage(1075116);
                spawned++;
                break;
            }
        }
        if (spawned > 0)
        {
            _calledReinforcements = true;
            this.MarkDirty();
        }
    }

    internal void CallInitialSatyrs()
    {
        if (_satyrs.Count > 0 || !Region.IsPartOf("Blighted Grove"))
        {
            return;
        }

        foreach (var point in GroveSatyrs)
        {
            if (!Map.CanSpawnMobile(point))
            {
                continue;
            }
            var satyr = new EnslavedSatyr { Home = point, RangeHome = 5, FightMode = FightMode.Closest };
            satyr.MoveToWorld(point, Map);
            _satyrs.Add(satyr);
        }
        this.MarkDirty();
    }

    public override void GenerateLoot()
    {
        AddLoot(LootPack.SuperBoss, 8);
        AddLoot(PerchParrotItem.Loot);
    }

    public override void OnDeath(Container corpse)
    {
        base.OnDeath(corpse);
        corpse.DropItem(new DiseasedBark());
        corpse.DropItem(new EternallyCorruptTree());
        var wine = Utility.RandomMinMax(4, 11);
        for (var i = 0; i < wine; i++)
        {
            corpse.DropItem(new MelisandesFermentedWine());
        }
        if (Utility.RandomDouble() < .60)
        {
            corpse.DropItem(new PerchParrotItem());
        }
        if (Utility.RandomDouble() < 0.2225)
        {
            var prize = Utility.Random(3);
            if (prize == 0)
            {
                corpse.DropItem(new MelisandesHairDye());
            }
            else if (prize == 1)
            {
                corpse.DropItem(new MelisandesCorrodedHatchet());
            }
            else
            {
                corpse.DropItem(new AlbinoSquirrelImprisonedInCrystal());
            }
        }
    }

    public override void OnDelete()
    {
        foreach (var satyr in _satyrs)
        {
            satyr?.Delete();
        }
        base.OnDelete();
    }
}
