// SPDX-License-Identifier: GPL-3.0-or-later
using ModernUO.Serialization;

namespace Server.Mobiles;

[SerializationGenerator(0)]
public sealed partial class GrayGoblinKeeper : AbyssGoblin
{
    [Constructible]
    public GrayGoblinKeeper() : base(AIType.AI_Melee, 1900)
    {
        SetStr(326);
        SetDex(79);
        SetInt(114);
        SetHits(186);
        SetStam(79);
        SetMana(114);
        SetResistance(ResistanceType.Physical, 45);
        SetResistance(ResistanceType.Fire, 33);
        SetResistance(ResistanceType.Cold, 25);
        SetResistance(ResistanceType.Poison, 20);
        SetResistance(ResistanceType.Energy, 10);
        SetSkill(SkillName.MagicResist, 129.9);
        SetSkill(SkillName.Tactics, 86.7);
        SetSkill(SkillName.Anatomy, 86.6);
        SetSkill(SkillName.Wrestling, 103.6);
    }

    public override string DefaultName => "a gray goblin keeper";
    public override string CorpseName => "a goblin keeper corpse";
}
