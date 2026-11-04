// SPDX-License-Identifier: GPL-3.0-or-later
using System.Net;
using Server;
using Server.Commands;
using Server.Mobiles;

namespace BritanniaReborn.HorseIntegrationFixtures;

public static class DragonBreathFixtures
{
    private sealed record Pair(BaseCreature Caster, OgreLord Target)
    {
        public int StartingHits { get; set; }
    }

    private static readonly Dictionary<Serial, Pair> _pairs = new();

    public static void Configure()
    {
        if (ServerConfiguration.GetOrUpdateSetting("britanniaReborn.isolatedHorseTests", false)
            && ServerConfiguration.GetOrUpdateSetting("britanniaReborn.isolatedDragonBreathTests", false))
        {
            CommandSystem.Register("DragonBreathFixture", AccessLevel.Player, Execute);
        }
    }

    private static void Cleanup(PlayerMobile owner)
    {
        if (_pairs.Remove(owner.Serial, out var pair))
        {
            pair.Caster.Delete();
            pair.Target.Delete();
        }
    }

    private static void Execute(CommandEventArgs args)
    {
        if (args.Mobile is not PlayerMobile owner || owner.NetState is not { } state
            || !IPAddress.IsLoopback(state.Address)
            || owner.Account?.Username?.StartsWith("brhorse-test-", StringComparison.Ordinal) != true)
        {
            return;
        }

        var operation = args.GetString(0);
        if (operation == "cleanup")
        {
            Cleanup(owner);
            owner.SendMessage("UCBREATH|clean");
            return;
        }
        if (operation == "prepare")
        {
            Prepare(owner, args.GetInt32(1), args.GetString(2));
            return;
        }
        if (!_pairs.TryGetValue(owner.Serial, out var pair) || pair.Caster.Deleted || pair.Target.Deleted)
        {
            return;
        }
        if (operation == "fire" && pair.StartingHits == 0)
        {
            var ability = pair.Caster.GetMonsterAbilities().OfType<FireBreath>().FirstOrDefault();
            if (ability == null || !ability.CanFireBreathTarget(pair.Caster, pair.Target)
                || !FixtureAIControls.Stopped(pair.Caster) || !FixtureAIControls.Stopped(pair.Target))
            {
                owner.SendMessage("UCBREATH|blocked|ability-or-target");
                return;
            }
            pair.StartingHits = pair.Target.Hits;
            // Invoke the creature's native ability. Both native timers and
            // damage run without fixture callbacks or modified statistics.
            ability.Trigger(MonsterAbilityTrigger.CombatAction, pair.Caster, pair.Target);
            owner.SendMessage($"UCBREATH|fire|{pair.StartingHits}");
        }
        else if (operation == "hits")
        {
            owner.SendMessage($"UCBREATH|hits|{pair.StartingHits}|{pair.Target.Hits}");
        }
    }

    private static void Prepare(PlayerMobile owner, int body, string name)
    {
        Cleanup(owner);
        Func<BaseCreature>? create = (body, name) switch
        {
            (12 or 59, "Dragon") => () => new Dragon(),
            (12 or 59, "GreaterDragon") => () => new GreaterDragon(),
            (60 or 61, "Drake") => () => new Drake(),
            _ => null
        };
        if (create == null || !AquaticFixtures.Prepare(owner, false))
        {
            owner.SendMessage("UCBREATH|blocked|arena-or-body");
            return;
        }

        for (var attempt = 0; attempt < 16; attempt++)
        {
            var caster = create();
            if (caster.Body.BodyID != body)
            {
                caster.Delete();
                continue;
            }
            var target = new OgreLord { Frozen = true };
            caster.MoveToWorld(new Point3D(owner.X + 1, owner.Y + 1, owner.Z), owner.Map);
            target.MoveToWorld(new Point3D(owner.X + 4, owner.Y + 1, owner.Z), owner.Map);
            FixtureAIControls.Stop(caster);
            FixtureAIControls.Stop(target);
            _pairs[owner.Serial] = new Pair(caster, target);
            owner.SendMessage($"UCBREATH|prepared|{caster.Serial.Value}|{target.Serial.Value}|{body}|{name}");
            return;
        }
        owner.SendMessage("UCBREATH|blocked|native-constructor");
    }
}
