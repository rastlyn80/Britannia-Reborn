// SPDX-License-Identifier: GPL-3.0-or-later
using ModernUO.Serialization;
using Server.Items;

namespace Server.Mobiles;

[SerializationGenerator(0)]
public partial class FireDaemon : BaseCreature
{
    private static readonly MonsterAbility[] _abilities = [MonsterAbilities.FireBreath];

    [Constructible]
    public FireDaemon() : base(AIType.AI_Mage, FightMode.Closest, 10, 1)
    {
        Body = 9;
        Hue = 1636;
        BaseSoundID = 0x47D;
        SetStr(504, 539);
        SetDex(126, 145);
        SetInt(329, 364);
        SetHits(1026, 1174);
        SetDamage(7, 14);

        SetDamageType(ResistanceType.Physical, 20);
        SetDamageType(ResistanceType.Fire, 80);
        SetResistance(ResistanceType.Physical, 45, 60);
        SetResistance(ResistanceType.Fire, 100);
        SetResistance(ResistanceType.Cold, -10, 0);
        SetResistance(ResistanceType.Poison, 20, 30);
        SetResistance(ResistanceType.Energy, 30, 40);
        SetSkill(SkillName.Anatomy, 75.5, 84.9);
        SetSkill(SkillName.MagicResist, 95.7, 109.8);
        SetSkill(SkillName.Tactics, 81.0, 98.6);
        SetSkill(SkillName.Wrestling, 40.2, 78.7);
        SetSkill(SkillName.EvalInt, 91.1, 104.5);
        SetSkill(SkillName.Magery, 91.3, 105.0);
        SetSkill(SkillName.Meditation, 90.1, 103.7);
        SetSkill(SkillName.DetectHidden, 66.0);
        Fame = 15000;
        Karma = -15000;
        VirtualArmor = 58;
    }

    public override string DefaultName => "a fire daemon";
    public override string CorpseName => "a fire daemon corpse";
    public override bool CanRummageCorpses => true;
    public override bool HasAura => true;
    public override Poison PoisonImmune => Poison.Regular;
    public override int TreasureMapLevel => 4;
    public override int Meat => 1;

    public override MonsterAbility[] GetMonsterAbilities() => _abilities;
    public override void AuraEffect(Mobile target) => target.SendLocalizedMessage(1008112);

    public override void GenerateLoot()
    {
        AddLoot(LootPack.FilthyRich);
        AddLoot(LootPack.Rich);
    }

    public override void GetSpeeds(out double activeSpeed, out double passiveSpeed)
    {
        activeSpeed = 0.2;
        passiveSpeed = 0.4;
    }
}
