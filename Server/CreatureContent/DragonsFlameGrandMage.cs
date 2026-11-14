// SPDX-License-Identifier: GPL-3.0-or-later
using ModernUO.Serialization;
using Server.Items;

namespace Server.Mobiles;

[SerializationGenerator(0)]
[TypeAlias("Server.Mobiles.MageDragonsFlameMage")]
public partial class DragonsFlameGrandMage : DragonsFlameMage
{
    [Constructible]
    public DragonsFlameGrandMage()
    {
        SetInt(500, 515);
        SetHits(800);
        SetDamage(15, 20);
        Fame = 25000;
        Karma = -25000;
        VirtualArmor = 60;
    }

    public override string DefaultName => "Black Order Grand Mage";
    public override string CorpseName => "a black order grand mage corpse";
    protected override double SectBadgeChance => 0.65;

    public override void OnDeath(Container corpse)
    {
        base.OnDeath(corpse);
        corpse.DropItem(new DragonFlameKey());
    }

    public override void GenerateLoot() => AddLoot(LootPack.FilthyRich, 6);
}
