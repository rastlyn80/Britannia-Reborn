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
    // Listed shorthands, else any tameable creature class by name.
    private static BaseCreature? Create(string kind) => kind.ToLowerInvariant() switch
    {
        "horse" => new Horse(),
        "packhorse" => new PackHorse(),
        "llama" => new Llama(),
        "packllama" => new PackLlama(),
        "desertostard" => new DesertOstard(),
        "forestostard" => new ForestOstard(),
        "dog" => new Dog(),
        "cat" => new Cat(),
        _ => AssemblyHandler.FindTypeByName(kind) is { IsAbstract: false } type && typeof(BaseCreature).IsAssignableFrom(type)
            ? Construct(type) as BaseCreature
            : null
    };

    // The constructor whose parameters are all optional (most ModernUO items
    // take "int amount = 1"), called with its defaults.
    private static object? Construct(Type type)
    {
        foreach (var constructor in type.GetConstructors())
        {
            var parameters = constructor.GetParameters();
            if (parameters.All(p => p.IsOptional))
            {
                return constructor.Invoke(parameters.Select(p => p.DefaultValue).ToArray());
            }
        }
        return null;
    }

    public static Result Conjure(Mobile mobile, string kind)
    {
        var pet = Create(kind);
        if (pet == null)
        {
            return Result.Fail("invalid", $"no creature type named {kind}");
        }
        if (!pet.Tamable)
        {
            pet.Delete();
            return Result.Fail("invalid", $"{kind} cannot be tamed");
        }
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
        switch (kind)
        {
            case "mage":
                // Every spell to cast, the skills to cast them well, reagents.
                mobile.Skills[SkillName.Magery].Base = 100.0;
                mobile.Skills[SkillName.EvalInt].Base = 100.0;
                pack.DropItem(new Spellbook(ulong.MaxValue));
                var bag = new Bag { Name = "reagents" };
                foreach (var reagent in new Item[] { new BlackPearl(100), new Bloodmoss(100), new Garlic(100), new Ginseng(100), new MandrakeRoot(100), new Nightshade(100), new SulfurousAsh(100), new SpidersSilk(100) })
                {
                    bag.DropItem(reagent);
                }
                pack.DropItem(bag);
                break;
            // Tools to try a trade; skills are left as they are, so gains show.
            case "lumberjack": pack.DropItem(new Hatchet()); break;
            case "miner": pack.DropItem(new Pickaxe()); pack.DropItem(new Shovel()); break;
            case "fisher": pack.DropItem(new FishingPole()); break;
            case "smith": pack.DropItem(new SmithHammer()); pack.DropItem(new IronIngot(100)); break;
            case "tailor": pack.DropItem(new SewingKit()); pack.DropItem(new Cloth(100)); break;
            case "carpenter": pack.DropItem(new Saw()); pack.DropItem(new Board(100)); break;
            case "tinker": pack.DropItem(new TinkerTools()); pack.DropItem(new IronIngot(100)); break;
            case "stats":
                // Strength, Dexterity (stamina) and Intelligence 100, all full.
                mobile.RawStr = 100;
                mobile.RawDex = 100;
                mobile.RawInt = 100;
                mobile.Hits = mobile.HitsMax;
                mobile.Stam = mobile.StamMax;
                mobile.Mana = mobile.ManaMax;
                break;
        }
        return new Result { Ok = true, Code = kind };
    }

    // Any ordinary item class by name into the backpack (stackables as one
    // pile, others up to 20 copies). Houses, boats and spawners are refused.
    public static Result Give(Mobile mobile, string name, int amount)
    {
        if (mobile.Backpack is not { } pack)
        {
            return Result.Fail("state", "no backpack");
        }
        if (AssemblyHandler.FindTypeByName(name) is not { IsAbstract: false } type || !typeof(Item).IsAssignableFrom(type) ||
            typeof(BaseMulti).IsAssignableFrom(type) || typeof(Server.Engines.Spawners.BaseSpawner).IsAssignableFrom(type))
        {
            return Result.Fail("invalid", $"no item type named {name}");
        }
        if (Construct(type) is not Item first)
        {
            return Result.Fail("invalid", $"cannot create {name}");
        }
        if (first.Stackable)
        {
            first.Amount = amount;
            pack.DropItem(first);
            return new Result { Ok = true, Code = "give" };
        }
        pack.DropItem(first);
        for (var i = 1; i < Math.Min(amount, 20); i++)
        {
            if (Construct(type) is Item copy)
            {
                pack.DropItem(copy);
            }
        }
        return new Result { Ok = true, Code = "give" };
    }

    public static Result Stat(Mobile mobile, string name, string value)
    {
        var full = value == "full";
        var number = full ? 0 : int.Parse(value);
        switch (name)
        {
            case "str": mobile.RawStr = number; mobile.Hits = mobile.HitsMax; break;
            case "dex": mobile.RawDex = number; mobile.Stam = mobile.StamMax; break;
            case "int": mobile.RawInt = number; mobile.Mana = mobile.ManaMax; break;
            case "hits": mobile.Hits = full ? mobile.HitsMax : Math.Min(number, mobile.HitsMax); break;
            case "stam": mobile.Stam = full ? mobile.StamMax : Math.Min(number, mobile.StamMax); break;
            default: mobile.Mana = full ? mobile.ManaMax : Math.Min(number, mobile.ManaMax); break;
        }
        return new Result { Ok = true, Code = "stat" };
    }

    public static Result Skill(Mobile mobile, string name, double value)
    {
        foreach (var skill in mobile.Skills)
        {
            if (skill != null && (string.Equals(skill.SkillName.ToString(), name, StringComparison.OrdinalIgnoreCase) ||
                string.Equals(skill.Name.Replace(" ", ""), name, StringComparison.OrdinalIgnoreCase)))
            {
                skill.Base = value;
                return new Result { Ok = true, Code = "skill" };
            }
        }
        return Result.Fail("invalid", $"no skill named {name}");
    }
}
