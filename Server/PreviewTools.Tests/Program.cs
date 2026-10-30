// SPDX-License-Identifier: GPL-3.0-or-later
using UltimaClone.PreviewTools.DevEdit;

// Offline checks: operation validation, ordering/revision conflicts, undo/redo
// ownership, reservations, deterministic journal/edit-set round trips and
// corrupted-journal rejection. Exit code is the number of failures.
var failures = 0;
var passes = 0;
void Check(bool condition, string name)
{
    if (condition) { passes++; } else { failures++; Console.WriteLine("FAIL " + name); }
}

DevEditRules Rules()
{
    var rules = new DevEditRules();
    rules.ApprovedAssets.UnionWith(new[] { 0x0E3D, 0x0E7E, 0x0C84 });
    return rules;
}

var now = new DateTime(2026, 10, 28, 12, 0, 0, DateTimeKind.Utc);
var session = new DevEditSession("test", "baseline-a", Rules());
const string Barrel = "s:1600:1590:20:3645:0";

// Validation: malformed and out-of-range commands change nothing.
Check(!session.Set("Ann", "s:1600:1590:20:3645", 0, "hide", now).Ok, "short static identity rejected");
Check(!session.Set("Ann", "s:10:10:0:1:0", 0, "hide", now).Ok, "static outside region rejected");
Check(!session.Set("Ann", Barrel, 0, "m:1620:1590:20:0:3645", now).Ok, "move beyond bounded distance rejected");
Check(!session.Set("Ann", Barrel, 0, "m:1601.5:1590:20:0:999", now).Ok, "unapproved replacement rejected");
Check(!session.Set("Ann", Barrel, 0, "m:1601.555:1590:20:0:3645", now).Ok, "non-canonical number rejected");
Check(!session.Set("Ann", Barrel, 0, "m:1601:1590:20:360:3645", now).Ok, "yaw out of range rejected");
Check(!session.Place("Ann", 999, "1600", "1590", 20, 0).Ok, "unapproved placement rejected");
Check(!session.Brush("Ann", "1600", "1590", "9", "4", "-", now).Ok, "oversized brush rejected");
Check(!session.Brush("Ann", "1600", "1590", "2", "0", "-", now).Ok, "no-op brush rejected");
Check(!session.Brush("Ann", "1089", "1409", "3", "4", "-", now).Ok, "brush leaving region rejected");
Check(!session.Set("Ann bad|name", Barrel, 0, "hide", now).Ok, "unattributable author rejected");
Check(session.Revision == 0 && session.Targets.Count == 0, "invalid operations leave the overlay unchanged");

// Accepted edits are ordered and attributed.
var hide = session.Set("Ann", Barrel, 0, "hide", now, "hide");
Check(hide.Ok && hide.Operation!.Seq == 1 && session.Current(Barrel).Author == "Ann", "hide accepted with attribution");
Check(!session.Set("Bob", Barrel, 0, "m:1601:1590:20:90:3645", now).Ok, "stale base revision rejected as conflict");
var move = session.Set("Bob", Barrel, 1, "m:1601:1590:20:90:3645", now, "move");
Check(move.Ok && session.Current(Barrel).Revision == 2, "edit from current revision accepted");

// Undo never overwrites someone else's newer change.
var undoAnn = session.Undo("Ann", 1, now);
Check(!undoAnn.Ok && undoAnn.Code == "conflict" && undoAnn.Detail.Contains("Bob"), "undo blocked by another editor's newer change");
Check(!session.Undo("Ann", 2, now).Ok, "cannot undo another editor's operation");
var undoBob = session.Undo("Bob", 2, now);
Check(undoBob.Ok && session.Current(Barrel).State == "hide", "own undo restores the previous state");
Check(!session.Undo("Bob", 2, now).Ok, "operation cannot be undone twice");
var redoBob = session.Redo("Bob", undoBob.Operation!.Seq, now);
Check(redoBob.Ok && session.Current(Barrel).State == "m:1601:1590:20:90:3645", "redo reapplies");
Check(!session.Redo("Bob", undoBob.Operation.Seq, now).Ok, "redo cannot repeat");

// Placement creates stable numbered targets.
var place = session.Place("Ann", 0x0E3D, "1602.25", "1591", 20, 45);
Check(place.Ok && place.Operation!.Changes[0].Target == "p:1", "placement assigns p:1");
Check(session.CheckTarget("p:2") != null, "unassigned placed id is unknown");

// Reservations.
Check(session.Reserve("Ann", "p:1", now).Ok, "reservation granted");
var reserved = session.Set("Bob", "p:1", place.Operation.Seq, "", now);
Check(!reserved.Ok && reserved.Code == "reserved", "reserved target refuses other editors");
Check(!session.Reserve("Bob", "p:1", now).Ok, "second reservation refused");
Check(session.Set("Bob", "p:1", place.Operation.Seq, "", now.AddSeconds(DevEditRules.ReservationSeconds + 1)).Ok, "expired reservation no longer blocks");
session.ReleaseAll("Ann");

// Terrain brush: deterministic falloff, region reservation, clamping.
var brush = session.Brush("Ann", "1650", "1650", "2", "8", "dirt", now);
Check(brush.Ok && brush.Operation!.Changes.Count == 13, "radius-2 brush touches 13 samples");
Check(session.Current("t:1650:1650").State == "h:8:dirt" && session.Current("t:1652:1650").State == "h:3:dirt" && session.Current("t:1651:1651").State == "h:4:dirt", "falloff is deterministic");
Check(session.Reserve("Bob", "r:1660:1650:3", now).Ok, "region reserved");
Check(session.Brush("Ann", "1657", "1650", "2", "4", "-", now).Code == "reserved", "brush overlapping a region reservation refused");
Check(!session.Reserve("Ann", "r:1658:1650:2", now).Ok, "overlapping region reservation refused");
session.ReleaseAll("Bob");
for (var i = 0; i < 6; i++) { session.Brush("Ann", "1650", "1650", "0", "10", "-", now); }
Check(session.Current("t:1650:1650").State == "h:40:dirt", "terrain delta is clamped");
var flatten = session.Brush("Ann", "1700", "1700", "0", "5", "-", now);
var back = session.Brush("Ann", "1700", "1700", "0", "-5", "-", now);
Check(back.Ok && session.Current("t:1700:1700").State == "" && session.Current("t:1700:1700").Revision == back.Operation!.Seq, "returning to baseline keeps the revision");

// Previews are validated but not persisted.
Check(session.Preview("Bob", "n", "a:3645:1600:1590:20:0").Ok, "valid placement preview");
Check(!session.Preview("Bob", "n", "a:999:1600:1590:20:0").Ok, "invalid preview rejected");
Check(session.Preview("Bob", "b:1650:1650:2:4:-", "").Ok, "brush preview");
var journal = session.Serialize();
Check(!journal.Contains("Bob\", \"n\"") && !journal.Contains("b:1650"), "previews are not written to the journal");

// Deterministic persistence and replay.
var reloaded = DevEditSession.Load(journal, Rules(), "test", "baseline-a");
Check(reloaded.Serialize() == journal, "journal round-trips byte for byte");
Check(reloaded.Current(Barrel).State == session.Current(Barrel).State && reloaded.Current(Barrel).Revision == session.Current(Barrel).Revision, "replay restores revisions");
Check(reloaded.Undo("Bob", redoBob.Operation!.Seq, now).Ok, "undo history survives restart");
Check(reloaded.Place("Ann", 0x0E3D, "1603", "1591", 20, 0).Operation!.Changes[0].Target == "p:2", "placed counter survives restart");
var tampered = journal.Replace("\"hide\"", "\"m:1601:1590:20:0:3645\"");
var refused = false;
try { DevEditSession.Load(tampered, Rules(), "test", "baseline-a"); } catch (InvalidDataException) { refused = true; }
Check(refused, "journal that does not replay is refused");
refused = false;
try { DevEditSession.Load(journal, Rules(), "other", "baseline-a"); } catch (InvalidDataException) { refused = true; }
Check(refused, "journal for another session is refused");

// Saved edit sets: deterministic, validated, imported as one undoable op.
var set = session.ExportSet();
Check(set == DevEditSession.Load(journal, Rules(), "test", "baseline-a").ExportSet(), "edit set export is deterministic");
var fresh = new DevEditSession("other", "baseline-a", Rules());
var import = fresh.Import("Cy", set, now);
Check(import.Ok && fresh.ExportSet().Contains(Barrel) && fresh.Current("t:1650:1650").State == "h:40:dirt", "edit set imports into another session");
Check(!new DevEditSession("x", "baseline-b", Rules()).Import("Cy", set, now).Ok, "edit set for another baseline refused");
Check(!fresh.Import("Cy", set.Replace("hide", "explode"), now).Ok, "malformed edit set refused");
Check(fresh.Undo("Cy", import.Operation!.Seq, now).Ok && fresh.Targets.All(t => t.Value.State == ""), "import is undoable");

// Batches: atomic, one operation, one undo; any invalid or stale target refuses all.
var group = new DevEditSession("group", "baseline-a", Rules());
var flowers = new[] { "s:1600:1590:20:3206:0", "s:1601:1590:20:3206:0", "s:1602:1590:20:3206:0" };
var batch = group.Batch("Ann", flowers.Select(t => (t, 0, "hide")).ToList(), now, "hide");
Check(batch.Ok && batch.Operation!.Changes.Count == 3 && group.Revision == 1, "batch applies three targets as one operation");
var mixed = group.Batch("Ann", new List<(string, int, string)> { (flowers[0], 1, ""), ("s:10:10:0:1:0", 0, "hide") }, now, "restore");
Check(!mixed.Ok && group.Current(flowers[0]).State == "hide" && group.Revision == 1, "one invalid target refuses the whole batch");
var stale = group.Batch("Bob", flowers.Select(t => (t, 0, "")).ToList(), now, "restore");
Check(!stale.Ok && stale.Code == "conflict" && group.Revision == 1, "stale base revision refuses the whole batch");
Check(!group.Batch("Ann", new List<(string, int, string)> { (flowers[0], 1, ""), (flowers[0], 1, "") }, now, "restore").Ok, "duplicate target refused");
Check(group.Undo("Ann", 1, now).Ok && flowers.All(t => group.Current(t).State == ""), "one undo reverts the whole batch");
Check(group.Preview("Ann", "g:12", "name~barrel;near=1602,1591,12").Ok && !group.Preview("Ann", "g:12", "NAME|x").Ok, "group previews carry a validated rule");

// Conversation queue: multi-part asks, answers, proposals, resolution.
var talk = new DevEditConversation();
Check(talk.AddPart("Ann", "1/2", "make the market square", out var none).Ok && none == null, "first ask part waits for the rest");
Check(talk.AddPart("Ann", "2/2", "look festive | please", out var asked).Ok && asked!.Text == "make the market square look festive  please", "ask assembled and cleaned");
Check(!talk.AddPart("Bob", "2/2", "orphan", out _).Ok, "out-of-order ask part refused");
Check(talk.Answer(asked.Id, "Claude", "Placing flowers along the square.").Ok && asked.Status == "answered", "answer recorded");
Check(talk.ProposePart(asked.Id, "Claude", "1/2", "place 3206 1600 1590 20 0", out var done1).Ok && !done1, "proposal line 1 of 2");
Check(talk.ProposePart(asked.Id, "Claude", "2/2", "place 3204 1601 1590 20 0", out var done2).Ok && done2 && asked.Proposal.Length == 2 && asked.Status == "proposed", "proposal complete");
Check(!talk.Resolve(asked.Id, "Claude", "applied").Ok, "only the asker resolves");
Check(talk.Resolve(asked.Id, "Ann", "applied").Ok && asked.Status == "applied", "asker marks applied");
Check(!talk.ProposePart(asked.Id, "Claude", "1/1", "undo", out _).Ok, "closed request takes no proposals");

var committedSession = new DevEditSession("commit", "baseline-a", Rules());
committedSession.Set("Ann", Barrel, 0, "hide", now);
var commitBatch = committedSession.Batch("Ann", new List<(string, int, string)> { (Barrel, 1, "") }, now, "commit");
Check(commitBatch.Ok && !committedSession.Undo("Ann", commitBatch.Operation!.Seq, now).Ok && committedSession.Current(Barrel).State == "", "a commit batch cannot be undone (would double-apply)");

Check(DevEditSession.AssistantMay("propose") && DevEditSession.AssistantMay("preview") && new[] { "set", "place", "brush", "batch", "undo", "redo", "lock", "save", "load", "pet", "kit" }.All(v => !DevEditSession.AssistantMay(v)), "assistant may propose and preview, never apply, undo, lock or load");
Check(DevEditSession.ValidPet("horse") && DevEditSession.ValidPet("cat") && !DevEditSession.ValidPet("dragon") && !DevEditSession.ValidPet("Horse"), "pet takes only the listed tame kinds");
Check(DevEditSession.ValidKit("mage") && !DevEditSession.ValidKit("gm") && !DevEditSession.ValidKit(""), "kit takes only the listed test kits");

Console.WriteLine($"DEV EDIT SESSION TESTS: {passes} passed, {failures} failed");
return failures;
