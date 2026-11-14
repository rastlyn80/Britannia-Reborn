// SPDX-License-Identifier: GPL-3.0-or-later
using ModernUO.Serialization;
using Server.Items;

namespace Server.Mobiles;

[SerializationGenerator(0)]
public sealed partial class WyvernRenowned : AbyssRenownedCreature
{
    [Constructible]
    public WyvernRenowned() : base(62, 243, 362)
    {
        SetStr(1370, 1422);
        SetDex(103, 151);
        SetInt(835, 1002);
        SetHits(2412, 2734);
        SetStam(103, 151);
        SetMana(835, 1002);
        SetDamage(29, 35);
        SetDamageType(ResistanceType.Physical, 75);
        SetDamageType(ResistanceType.Fire, 25);
        SetResistance(ResistanceType.Physical, 60, 70);
        SetResistance(ResistanceType.Fire, 80, 90);
        SetResistance(ResistanceType.Cold, 70, 80);
        SetResistance(ResistanceType.Poison, 60, 70);
        SetResistance(ResistanceType.Energy, 60, 70);
        SetSkill(SkillName.Magery, 107.7, 109.1);
        SetSkill(SkillName.Meditation, 63.9, 78.2);
        SetSkill(SkillName.EvalInt, 106.8, 111.1);
        SetSkill(SkillName.Wrestling, 108.6, 109.4);
        SetSkill(SkillName.MagicResist, 125.8, 127.6);
        SetSkill(SkillName.Tactics, 112.8, 123.7);
        Fame = 24000;
        Karma = -24000;
        VirtualArmor = 70;
    }

    public override string DefaultName => "Wyvern";
    public override string CorpseName => "Wyvern [Renowned] corpse";
    public override bool ReacquireOnMovement => true;
    public override Poison PoisonImmune => Poison.Deadly;
    public override Poison HitPoison => Poison.Deadly;
    public override bool AutoDispel => true;
    public override bool BardImmune => true;
    public override int TreasureMapLevel => 5;
    public override int Meat => 10;
    public override int Hides => 20;
    public override HideType HideType => HideType.Horned;
    public override int GetAttackSound() => 713;
    public override int GetAngerSound() => 718;
    public override int GetDeathSound() => 716;
    public override int GetHurtSound() => 721;
    public override int GetIdleSound() => 725;
    public override void GenerateLoot() => AddLoot(LootPack.UltraRich);
    protected override Item RollSharedArtifact() => CreateSharedArtifact();
}
