// SPDX-License-Identifier: GPL-3.0-or-later
using ModernUO.Serialization;
using Server.Commands;
using Server.Items;

namespace Server.Mobiles;

[SerializationGenerator(0)]
public abstract partial class AlchemistInspector : BaseVendor
{
    private readonly List<SBInfo> _stock = new();

    protected AlchemistInspector(string title) : base(title)
    {
        CantWalk = true;
        SetSkill(SkillName.Alchemy, 85.0, 100.0);
        SetSkill(SkillName.TasteID, 65.0, 88.0);
    }

    protected abstract int SkinHue { get; }
    protected abstract int HornGraphic { get; }
    protected abstract int HornHue { get; }
    protected abstract (int Legs, int Kilt, int Chest, int Arms) OutfitHues { get; }
    protected virtual bool InspectsKegs => false;
    protected override List<SBInfo> SBInfos => _stock;

    public override void InitSBInfo() => _stock.Add(new SBAlchemist());

    public override void InitBody()
    {
        InitStats(100, 100, 25);
        Female = true;
        Race = Race.Gargoyle;
        Body = Race.AliveBody(this);
        Hue = SkinHue;
        HairItemID = HornGraphic;
        HairHue = HornHue;
        Name = DefaultName;
    }

    public override void InitOutfit()
    {
        var (legs, kilt, chest, arms) = OutfitHues;
        AddItem(new GargishClothLegsType2 { Hue = legs });
        AddItem(new GargishClothKiltType2 { Hue = kilt });
        AddItem(new GargishClothChestType2 { Hue = chest });
        AddItem(new GargishClothArmsType2 { Hue = arms });
    }

    public override bool OnDragDrop(Mobile from, Item offered)
    {
        if (from is not PlayerMobile { Alive: true } || from.Map != Map || !from.InRange(this, 2) || !from.InLOS(this))
        {
            return false;
        }

        Item? inspected = null;
        if (offered is BaseIngot ingot && InspectedAlchemyGoods.CanInspect(ingot.Resource))
        {
            if (ingot.Amount != 20)
            {
                SayTo(from, ingot.Amount < 20 ? 1113036 : 1113037);
                return false;
            }
            var entry = InspectedAlchemyGoods.ForResource(ingot.Resource);
            inspected = new InspectedAlchemyGoods(0x1BEA, entry.Hue, entry.Label, entry.Name);
        }
        else if (InspectsKegs && offered is PotionKeg keg)
        {
            if (keg.Type is not (PotionEffect.RefreshTotal or PotionEffect.PoisonGreater))
            {
                SayTo(from, 1113039);
                return false;
            }
            if (keg.Held < 100)
            {
                SayTo(from, 1113038);
                return false;
            }
            var poison = keg.Type == PotionEffect.PoisonGreater;
            inspected = new InspectedAlchemyGoods(0x1940, poison ? 2425 : 2418, 0,
                poison ? "Inspected Keg of Greater Poison" : "Inspected Keg of Total Refreshment");
        }

        if (inspected == null)
        {
            SayTo(from, 1113035);
            return false;
        }
        if (from.Backpack?.TryDropItem(from, inspected, true) != true)
        {
            inspected.Delete();
            return false;
        }
        offered.Delete();
        SayTo(from, 1113040);
        from.SendLocalizedMessage(1113041);
        return true;
    }

    public new static void Initialize() => CommandSystem.Register("PlaceAbyssAlchemists", AccessLevel.Administrator, Place);

    private static void Place(CommandEventArgs args)
    {
        var staff = args.Mobile;
        var map = Map.TerMur;
        var house = new Point3D(771, 3475, -20);
        if (staff.Map != map || !staff.InRange(house, 8))
        {
            staff.SendMessage("Stand by the Royal City alchemist's shop.");
            return;
        }

        var hasThepem = false;
        var hasZosilem = false;
        foreach (var vendor in map.GetMobilesInRange<AlchemistInspector>(house, 8))
        {
            hasThepem |= vendor is Thepem;
            hasZosilem |= vendor is Zosilem;
        }

        var second = new Point3D(house.X + 1, house.Y, house.Z);
        if ((!hasThepem && !map.CanFit(house, 16, checkMobiles: false)) ||
            (!hasZosilem && !map.CanFit(second, 16, checkMobiles: false)))
        {
            staff.SendMessage("The Royal City alchemist's shop has no clear floor for the inspectors.");
            return;
        }
        if (!hasThepem)
        {
            new Thepem().MoveToWorld(house, map);
        }
        if (!hasZosilem)
        {
            new Zosilem().MoveToWorld(second, map);
        }
        staff.SendMessage("Thepem and Zosilem are present in the Royal City alchemist's shop.");
    }
}

[SerializationGenerator(0)]
public sealed partial class Thepem : AlchemistInspector
{
    [Constructible]
    public Thepem() : base("the Apprentice")
    {
    }

    public override string DefaultName => "Thepem";
    protected override int SkinHue => 0x86E1;
    protected override int HornGraphic => 0x42AB;
    protected override int HornHue => 0x385;
    protected override (int, int, int, int) OutfitHues => (0x70F, 0x742, 0x4C3, 0x738);
}

[SerializationGenerator(0)]
public sealed partial class Zosilem : AlchemistInspector
{
    [Constructible]
    public Zosilem() : base("the Alchemist")
    {
    }

    public override string DefaultName => "Zosilem";
    protected override int SkinHue => 0x86EA;
    protected override int HornGraphic => 0x4273;
    protected override int HornHue => 0x323;
    protected override (int, int, int, int) OutfitHues => (0x736, 0x73D, 0x38B, 0x711);
    protected override bool InspectsKegs => true;
}
