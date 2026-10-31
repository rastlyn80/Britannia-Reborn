// SPDX-License-Identifier: GPL-3.0-or-later
using Server;
using Server.Items;
using Server.Network;
using Server.Spells;

namespace UltimaClone.PreviewTools;

// The client's quickbar shows how long each kind of action must wait. The
// protocol has no cooldown packet, so this reads ModernUO's own timers (it
// never sets them) and tells the player's client whenever one changes, as a
// system line "UCWAIT1|kind|milliseconds" that the client hides:
// - skill: Mobile.NextSkillTime, which every skill sets to its real delay
//   (Peacemaking's 30 s while its target is open, then 10 s or 5 s, taming
//   and begging resetting it early, and so on);
// - spell: while casting, the cast delay plus recovery from the spell's own
//   start; afterwards Mobile.NextSpellTime (faster casting included);
// - bandage: the running BandageContext's remaining time;
// - heal_potion: -1 while the heal potion lock is held, 0 when it lifts.
// Read-only and per connected player; disable with ultimaClone.actionTimers.
public static class ActionTimers
{
    private const int Tolerance = 150;
    private static readonly Dictionary<Mobile, long[]> _sent = new();

    public static void Configure()
    {
        if (!ServerConfiguration.GetOrUpdateSetting("ultimaClone.actionTimers", true)) return;
        Server.Timer.DelayCall(TimeSpan.FromSeconds(1), TimeSpan.FromMilliseconds(100), Poll);
    }

    private static void Poll()
    {
        var now = Core.TickCount;
        foreach (var state in NetState.Instances)
        {
            if (state.Mobile is not { Deleted: false } mobile) continue;
            if (!_sent.TryGetValue(mobile, out var last))
            {
                last = new long[] { 0, 0, 0, 0 };
                _sent[mobile] = last;
            }
            Report(mobile, last, 0, "skill", Math.Max(0, mobile.NextSkillTime - now));
            Report(mobile, last, 1, "spell", SpellWait(mobile, now));
            var bandage = BandageContext.GetContext(mobile);
            Report(mobile, last, 2, "bandage", bandage?.Running == true ? Math.Max(0, (long)(bandage.Next - Core.Now).TotalMilliseconds) : 0);
            Report(mobile, last, 3, "heal_potion", mobile.CanBeginAction<BaseHealPotion>() ? 0 : -1);
        }
        if (_sent.Count > NetState.Instances.Count * 2 + 16)
        {
            foreach (var gone in _sent.Keys.Where(m => m.NetState == null || m.Deleted).ToList()) _sent.Remove(gone);
        }
    }

    private static long SpellWait(Mobile mobile, long now)
    {
        if (mobile.Spell is Spell { State: SpellState.Casting } spell)
        {
            var end = spell.StartCastTime + (long)(spell.GetCastDelay() + spell.GetCastRecovery()).TotalMilliseconds;
            return Math.Max(0, end - now);
        }
        return Math.Max(0, mobile.NextSpellTime - now);
    }

    // Sends when the wait's end moves (a new action, or the server cutting it
    // short) or when it becomes ready; a running countdown is not resent.
    private static void Report(Mobile mobile, long[] last, int slot, string kind, long wait)
    {
        var now = Core.TickCount;
        var end = wait > 0 ? now + wait : wait;
        var previous = last[slot];
        if (wait > 0 && previous > 0 && Math.Abs(previous - end) <= Tolerance) return;
        if (wait <= 0 && previous == wait) return;
        if (wait == 0 && previous > 0 && previous <= now + Tolerance)
        {
            last[slot] = 0;
            return; // ran out on its own; the client's countdown already shows ready
        }
        last[slot] = end;
        mobile.SendMessage($"UCWAIT1|{kind}|{wait}");
    }
}
