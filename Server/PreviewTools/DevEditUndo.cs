// SPDX-License-Identifier: GPL-3.0-or-later
using Server;
using Server.Mobiles;
using UltimaClone.PreviewTools.DevEdit;

namespace UltimaClone.PreviewTools;

// Undo for the server-only changes (give, pet, stat, skill, kit): before each
// one the developer's stats, skills, follower limit, account level, backpack
// contents and pets are noted; "revert <request> <that request>" restores the
// values and deletes what the change created. World edits keep their own undo.
public static class DevEditUndo
{
    private sealed class Snapshot
    {
        public int Request;
        public int Str, Dex, Int, FollowersMax;
        public AccessLevel Access;
        public double[] Skills = [];
        public HashSet<Serial> Items = [];
        public HashSet<Serial> Pets = [];
        public HashSet<Serial> NewItems = [];
        public HashSet<Serial> NewPets = [];
    }

    private const int Keep = 50;
    private static readonly Dictionary<Serial, List<Snapshot>> History = new();

    private static HashSet<Serial> PackItems(Mobile mobile)
    {
        var found = new HashSet<Serial>();
        if (mobile.Backpack is { } pack)
        {
            foreach (var item in pack.FindItemsByType<Item>())
            {
                found.Add(item.Serial);
            }
        }
        return found;
    }

    private static HashSet<Serial> Pets(Mobile mobile)
    {
        var found = new HashSet<Serial>();
        foreach (var other in World.Mobiles.Values)
        {
            if (other is BaseCreature { Controlled: true } creature && creature.ControlMaster == mobile)
            {
                found.Add(creature.Serial);
            }
        }
        return found;
    }

    public static object Before(Mobile mobile, int request)
    {
        var skills = new double[mobile.Skills.Length];
        for (var i = 0; i < skills.Length; i++)
        {
            skills[i] = mobile.Skills[i]?.Base ?? 0;
        }
        return new Snapshot
        {
            Request = request, Str = mobile.RawStr, Dex = mobile.RawDex, Int = mobile.RawInt,
            FollowersMax = mobile.FollowersMax, Access = mobile.AccessLevel, Skills = skills,
            Items = PackItems(mobile), Pets = Pets(mobile)
        };
    }

    // After a successful change: remember what it created.
    public static void After(Mobile mobile, object before)
    {
        var snapshot = (Snapshot)before;
        snapshot.NewItems = PackItems(mobile);
        snapshot.NewItems.ExceptWith(snapshot.Items);
        snapshot.NewPets = Pets(mobile);
        snapshot.NewPets.ExceptWith(snapshot.Pets);
        if (!History.TryGetValue(mobile.Serial, out var list))
        {
            History[mobile.Serial] = list = [];
        }
        list.Add(snapshot);
        if (list.Count > Keep)
        {
            list.RemoveAt(0);
        }
    }

    public static Result Revert(Mobile mobile, int request)
    {
        var index = History.TryGetValue(mobile.Serial, out var list) ? list.FindIndex(s => s.Request == request) : -1;
        if (list == null || index < 0)
        {
            return Result.Fail("invalid", "nothing to undo for that change (only changes since the server started)");
        }
        var s = list[index];
        list.RemoveAt(index);
        foreach (var serial in s.NewItems)
        {
            World.FindItem(serial)?.Delete();
        }
        foreach (var serial in s.NewPets)
        {
            World.FindMobile(serial)?.Delete();
        }
        mobile.RawStr = s.Str;
        mobile.RawDex = s.Dex;
        mobile.RawInt = s.Int;
        mobile.FollowersMax = s.FollowersMax;
        if (mobile.AccessLevel != s.Access)
        {
            if (mobile.Account is { } account)
            {
                account.AccessLevel = s.Access;
            }
            mobile.AccessLevel = s.Access;
        }
        for (var i = 0; i < s.Skills.Length && i < mobile.Skills.Length; i++)
        {
            if (mobile.Skills[i] is { } skill)
            {
                skill.Base = s.Skills[i];
            }
        }
        return new Result { Ok = true, Code = "reverted" };
    }
}
