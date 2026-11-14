// SPDX-License-Identifier: GPL-3.0-or-later
using ModernUO.Serialization;

namespace Server.Items;

[SerializationGenerator(0)]
public sealed partial class InspectedAlchemyGoods : Item
{
    [SerializableField(0)]
    private int _localizedName;

    public InspectedAlchemyGoods(int graphic, int hue, int localizedName, string? plainName) : base(graphic)
    {
        _localizedName = localizedName;
        Hue = hue;
        Name = plainName;
    }

    public override int LabelNumber => _localizedName == 0 ? base.LabelNumber : _localizedName;

    public static bool CanInspect(CraftResource resource) =>
        resource is CraftResource.DullCopper or CraftResource.ShadowIron or CraftResource.Bronze
            or CraftResource.Gold or CraftResource.Agapite or CraftResource.Verite or CraftResource.Valorite;

    public static (int Hue, int Label, string? Name) ForResource(CraftResource resource) => resource switch
    {
        CraftResource.DullCopper => (2419, 1113021, null),
        CraftResource.ShadowIron => (2406, 1113022, null),
        CraftResource.Bronze => (2418, 1113024, null),
        CraftResource.Gold => (2213, 1113027, null),
        CraftResource.Agapite => (2425, 1113770, null),
        CraftResource.Verite => (2207, 0, "Pile of Inspected Verite Ingots"),
        CraftResource.Valorite => (2219, 0, "Pile of Inspected Valorite Ingots"),
        _ => throw new ArgumentOutOfRangeException(nameof(resource))
    };
}
