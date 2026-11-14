// SPDX-License-Identifier: GPL-3.0-or-later
using ModernUO.Serialization;
using Server.Items;

namespace Server.Mobiles;

[SerializationGenerator(0)]
public partial class TigersClawMaster : TigersClawThief
{
    [Constructible]
    public TigersClawMaster()
    {
        SetStr(440, 460);
        SetHits(850, 875);
        SetDamage(15, 20);
        Fame = 25000;
        Karma = -25000;
        VirtualArmor = 60;
    }

    public override string DefaultName => "Black Order Master";
    public override string CorpseName => "a black order master corpse";
    protected override double SectBadgeChance => 0.65;

    public override void OnDeath(Container corpse)
    {
        base.OnDeath(corpse);
        corpse.DropItem(new TigerClawKey());
    }

    public override void GenerateLoot() => AddLoot(LootPack.FilthyRich, 6);
}
