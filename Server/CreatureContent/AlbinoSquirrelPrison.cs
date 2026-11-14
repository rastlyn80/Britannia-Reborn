// SPDX-License-Identifier: GPL-3.0-or-later
using ModernUO.Serialization;
using Server.Mobiles;

namespace Server.Items
{
    [SerializationGenerator(0)]
    public sealed partial class AlbinoSquirrelImprisonedInCrystal : BaseImprisonedMobile
    {
        [Constructible]
        public AlbinoSquirrelImprisonedInCrystal() : base(0x1F1C)
        {
            Hue = 0x482;
            Weight = 1.0;
        }

        public override int LabelNumber => 1075004;
        public override BaseCreature Summon => new AlbinoSquirrel();
    }
}

namespace Server.Mobiles
{
    [SerializationGenerator(0)]
    public sealed partial class AlbinoSquirrel : Squirrel
    {
        [Constructible]
        public AlbinoSquirrel() => Hue = 0x482;

        public override string DefaultName => "an albino squirrel";
        public override bool DeleteOnRelease => true;

        public override void GetProperties(IPropertyList list)
        {
            base.GetProperties(list);
            list.Add(1049646);
        }
    }
}
