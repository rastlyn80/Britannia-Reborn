// SPDX-License-Identifier: GPL-3.0-or-later
using ModernUO.Serialization;
using Server.Items;

namespace Server.Mobiles;

[SerializationGenerator(0)]
public sealed partial class Gremlin : BaseCreature
{
    [Constructible]
    public Gremlin() : base(AIType.AI_Archer, FightMode.Closest, 10, 6)
    {
        Body = 724;
        SetStr(106);
        SetDex(130);
        SetInt(36);
        SetHits(70);
        SetDamage(5, 7);
        SetDamageType(ResistanceType.Physical, 100);
        SetResistance(ResistanceType.Physical, 26);
        SetResistance(ResistanceType.Fire, 36);
        SetResistance(ResistanceType.Cold, 22);
        SetResistance(ResistanceType.Poison, 17);
        SetResistance(ResistanceType.Energy, 30);
        SetSkill(SkillName.Anatomy, 78.5);
        SetSkill(SkillName.MagicResist, 82.5);
        SetSkill(SkillName.Tactics, 65.3);
        SetSkill(SkillName.Archery, 65.3);
        AddItem(new Bow());
        PackItem(new Arrow(Utility.RandomMinMax(60, 80)));
        PackItem(new Apple(5));
    }

    public override string DefaultName => "a gremlin";
    public override string CorpseName => "a gremlin corpse";

    public override void GetSpeeds(out double activeSpeed, out double passiveSpeed)
    {
        activeSpeed = 0.2;
        passiveSpeed = 0.4;
    }

    public override void GenerateLoot() => AddLoot(LootPack.Rich);

    public override void OnDeath(Container corpse)
    {
        base.OnDeath(corpse);
        UnderworldFortune.DropCoin(corpse, 0.01);
    }
}
