// SPDX-License-Identifier: GPL-3.0-or-later
using ModernUO.Serialization;

namespace Server.Items;

[SerializationGenerator(0)]
public sealed partial class Yeast : Item
{
    [SerializableField(0, getter: "public", setter: "private")]
    private int _bacterialResistance;

    [Constructible]
    public Yeast() : base(3624)
    {
        Hue = 2418;
        BacterialResistance = Utility.Random(100) switch
        {
            <= 5 => 5,
            <= 10 => 4,
            <= 20 => 3,
            <= 40 => 2,
            _ => 1
        };
    }

    public override int LabelNumber => 1150453;

    public override void GetProperties(IPropertyList list)
    {
        base.GetProperties(list);
        var grade = _bacterialResistance switch
        {
            1 => "--",
            2 => "-",
            3 => "+-",
            4 => "+",
            _ => "++"
        };
        list.Add(1150455, $"{grade}");
    }
}
