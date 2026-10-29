// SPDX-License-Identifier: GPL-3.0-or-later
using Server;
using Server.Mobiles;
using UltimaClone.PreviewTools.DevEdit;

namespace UltimaClone.PreviewTools;

// "pet <kind>": a tame creature at the developer's feet, following them. It is
// an ordinary ModernUO creature in the world save (server-only; nothing goes
// to Git), so it can be ridden, released or deleted the usual way.
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
}
