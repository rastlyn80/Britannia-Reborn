// SPDX-License-Identifier: GPL-3.0-or-later
using ModernUO.Serialization;
using Server.Items;

namespace Server.Mobiles;

[SerializationGenerator(0)]
public partial class SerpentsFangHighExecutioner : SerpentsFangAssassin
{
    [Constructible]
    public SerpentsFangHighExecutioner()
    {
        SetStr(545, 560);
        SetHits(800);
        SetStam(190, 205);
        SetDamage(15, 20);
        Fame = 25000;
        Karma = -25000;
        VirtualArmor = 60;
    }

    public override string DefaultName => "Black Order High Executioner";
    public override string CorpseName => "a black order high executioner corpse";
    protected override double SectBadgeChance => 0.65;

    public override void AlterMeleeDamageFrom(Mobile from, ref int damage)
    {
        base.AlterMeleeDamageFrom(from, ref damage);
        if (from != null && damage >= 2)
        {
            from.Damage(damage / 2, from);
        }
    }

    public override void OnDeath(Container corpse)
    {
        base.OnDeath(corpse);
        corpse.DropItem(new SerpentFangKey());
    }

    public override void GenerateLoot() => AddLoot(LootPack.FilthyRich, 6);
}
