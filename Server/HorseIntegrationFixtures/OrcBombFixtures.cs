// SPDX-License-Identifier: GPL-3.0-or-later
using System.Net;
using Server;
using Server.Commands;
using Server.Mobiles;

namespace BritanniaReborn.HorseIntegrationFixtures;

public static class OrcBombFixtures
{
    private sealed record Trial(OrcBomber Bomber, OgreLord Target)
    {
        public int StartingHits { get; set; }
    }

    private static readonly Dictionary<Serial, Trial> _trials = new();

    public static void Configure()
    {
        if (ServerConfiguration.GetOrUpdateSetting("britanniaReborn.isolatedHorseTests", false)
            && ServerConfiguration.GetOrUpdateSetting("britanniaReborn.isolatedOrcBombTests", false))
        {
            CommandSystem.Register("OrcBombFixture", AccessLevel.Player, Execute);
        }
    }

    private static void Cleanup(PlayerMobile owner)
    {
        if (_trials.Remove(owner.Serial, out var trial))
        {
            trial.Bomber.Delete();
            trial.Target.Delete();
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
            owner.SendMessage("UCBOMB|clean");
            return;
        }
        if (operation == "prepare")
        {
            Prepare(owner);
            return;
        }
        if (!_trials.TryGetValue(owner.Serial, out var trial) || trial.Bomber.Deleted || trial.Target.Deleted)
        {
            return;
        }

        if (operation == "throw" && trial.StartingHits == 0)
        {
            if (!FixtureAIControls.Stopped(trial.Bomber) || !FixtureAIControls.Stopped(trial.Target)
                || !trial.Bomber.InRange(trial.Target, 12) || !trial.Bomber.InLOS(trial.Target)
                || !trial.Bomber.CanBeHarmful(trial.Target))
            {
                owner.SendMessage("UCBOMB|blocked|target");
                return;
            }
            trial.StartingHits = trial.Target.Hits;
            trial.Bomber.ThrowBomb(trial.Target);
            owner.SendMessage($"UCBOMB|throw|{trial.StartingHits}");
        }
        else if (operation == "hits")
        {
            owner.SendMessage($"UCBOMB|hits|{trial.StartingHits}|{trial.Target.Hits}");
        }
    }

    private static void Prepare(PlayerMobile owner)
    {
        Cleanup(owner);
        if (!AquaticFixtures.Prepare(owner, false))
        {
            owner.SendMessage("UCBOMB|blocked|arena");
            return;
        }
        var bomber = new OrcBomber();
        var target = new OgreLord { Frozen = true };
        bomber.MoveToWorld(new Point3D(owner.X + 1, owner.Y + 1, owner.Z), owner.Map);
        target.MoveToWorld(new Point3D(owner.X + 4, owner.Y + 1, owner.Z), owner.Map);
        FixtureAIControls.Stop(bomber);
        FixtureAIControls.Stop(target);
        _trials[owner.Serial] = new Trial(bomber, target);
        owner.SendMessage($"UCBOMB|prepared|{bomber.Serial.Value}|{target.Serial.Value}|{bomber.Body.BodyID}");
    }
}
