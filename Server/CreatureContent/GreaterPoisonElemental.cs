// SPDX-License-Identifier: GPL-3.0-or-later
using ModernUO.Serialization;
using Server.Items;

namespace Server.Mobiles;

[SerializationGenerator(0)]
public sealed partial class GreaterPoisonElemental : BaseCreature
{
    [Constructible]
    public GreaterPoisonElemental() : base(AIType.AI_Mage, FightMode.Closest, 10, 1)
    {
        Body = 162;
        Hue = 667;
        BaseSoundID = 263;
        SetStr(700, 771);
        SetDex(195, 203);
        SetInt(650, 691);
        SetHits(650, 702);
        SetStam(300, 322);
        SetMana(500, 530);
        SetDamage(12, 18);
        SetDamageType(ResistanceType.Physical, 10);
        SetDamageType(ResistanceType.Poison, 90);
        SetResistance(ResistanceType.Physical, 60, 70);
        SetResistance(ResistanceType.Fire, 20, 30);
        SetResistance(ResistanceType.Cold, 20, 30);
        SetResistance(ResistanceType.Poison, 100);
        SetResistance(ResistanceType.Energy, 40, 50);
        SetSkill(SkillName.EvalInt, 80.1, 110);
        SetSkill(SkillName.Magery, 80.1, 97);
        SetSkill(SkillName.Meditation, 80.2, 105.8);
        SetSkill(SkillName.Poisoning, 100.1, 114.9);
        SetSkill(SkillName.MagicResist, 85.2, 93.2);
        SetSkill(SkillName.Tactics, 80.1, 100);
        SetSkill(SkillName.Wrestling, 75, 88.3);
        SetSkill(SkillName.DetectHidden, 71.5);
        Fame = 12500;
        Karma = -12500;
        VirtualArmor = 70;
        PackItem(new Nightshade(4));
        PackItem(new LesserPoisonPotion());
    }

    public override string DefaultName => "Greater Poison Elemental";
    public override string CorpseName => "a poison elemental corpse";
    public override bool BleedImmune => true;
    public override Poison PoisonImmune => Poison.Lethal;
    public override Poison HitPoison => Poison.Lethal;
    public override double HitPoisonChance => 0.75;
    public override int TreasureMapLevel => 5;

    public override void GenerateLoot()
    {
        AddLoot(LootPack.FilthyRich);
        AddLoot(LootPack.Rich);
        AddLoot(LootPack.MedScrolls);
    }

    public override void OnDeath(Container corpse)
    {
        base.OnDeath(corpse);
        UnderworldFortune.DropCoin(corpse, 0.03);
    }
}
