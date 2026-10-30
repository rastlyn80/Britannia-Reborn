// SPDX-License-Identifier: GPL-3.0-or-later
using Server;
using Server.Items;
using Server.Mobiles;
using UltimaClone.PreviewTools.DevEdit;

namespace UltimaClone.PreviewTools;

// "pet <kind>": a tame creature at the developer's feet, following them. It is
// an ordinary ModernUO creature in the world save (server-only; nothing goes
// to Git), so it can be ridden, released or deleted the usual way.
// "kit <kind>": skills and ordinary items for testing a system, likewise.
public static class DevEditPets
{
    private static BaseCreature Create(string kind) => kind switch
    {
        "horse" => new Horse(),
        "packhorse" => new PackHorse(),
        "llama" => new Llama(),
        "packllama" => new PackLlama(),
        "desertostard" => new DesertOstard(),
        "forestostard" => new ForestOstard(),
        "dog" => new Dog(),
        _ => new Cat()
    };

    public static Result Conjure(Mobile mobile, string kind)
    {
        var pet = Create(kind);
        if (!pet.SetControlMaster(mobile))
        {
            pet.Delete();
            return Result.Fail("followers", "too many followers to control another creature");
        }
        pet.MoveToWorld(mobile.Location, mobile.Map);
        return new Result { Ok = true, Code = "pet" };
    }

    public static Result Kit(Mobile mobile, string kind)
    {
        if (mobile.Backpack is not { } pack)
        {
            return Result.Fail("state", "no backpack");
        }
        // "mage": every spell to cast, the skills to cast them well, reagents.
        mobile.Skills[SkillName.Magery].Base = 100.0;
        mobile.Skills[SkillName.EvalInt].Base = 100.0;
        pack.DropItem(new Spellbook(ulong.MaxValue));
        var bag = new Bag { Name = "reagents" };
        foreach (var reagent in new Item[] { new BlackPearl(100), new Bloodmoss(100), new Garlic(100), new Ginseng(100), new MandrakeRoot(100), new Nightshade(100), new SulfurousAsh(100), new SpidersSilk(100) })
        {
            bag.DropItem(reagent);
        }
        pack.DropItem(bag);
        return new Result { Ok = true, Code = kind };
    }
}
