// SPDX-License-Identifier: GPL-3.0-or-later
namespace UltimaClone.PreviewTools.DevEdit;

// Shared request queue for talking to the world. An editor asks in plain
// language; the client's own interpreter, or an assistant connected as an
// editor (Claude Code through scripts/dev-edit-bridge.ps1), answers and may
// propose edit commands. Proposals are only text here: they are applied by the
// asking editor's client after that editor confirms the scope, and every
// resulting edit still goes through the normal validated session operations.
public sealed class Ask
{
    public int Id;
    public string Author = "";
    public string Text = "";
    public string Status = "open"; // open, answered, proposed, applied, declined
    public List<string> Answers = new();
    public string ProposedBy = "";
    public string[] Proposal = Array.Empty<string>();
}

public sealed class DevEditConversation
{
    public const int MaxText = 440;
    public const int MaxProposal = 32;
    public const int Retained = 50;
    private readonly List<Ask> _asks = new();
    private readonly Dictionary<string, (int Total, List<string> Parts)> _partialAsks = new();
    private readonly Dictionary<(int, string), string[]> _partialProposals = new();
    private int _next = 1;

    public IReadOnlyList<Ask> Asks => _asks;

    public Ask? Find(int id) => _asks.FirstOrDefault(a => a.Id == id);

    // Replies travel as UCEDIT1 fields separated by '|'; keep text printable.
    public static string Clean(string text) =>
        new string(text.Where(c => c >= ' ' && c != '|' && c != '\u007f').ToArray()).Trim();

    private static bool Part(string spec, out int part, out int total)
    {
        part = total = 0;
        var pieces = spec.Split('/');
        return pieces.Length == 2 && int.TryParse(pieces[0], out part) && int.TryParse(pieces[1], out total) &&
               total is >= 1 and <= 8 && part >= 1 && part <= total;
    }

    // Speech commands are limited to 128 characters, so long requests arrive in
    // numbered parts ("1/2"); the ask exists once every part has arrived.
    public Result AddPart(string author, string spec, string text, out Ask? ask)
    {
        ask = null;
        text = Clean(text);
        if (!Part(spec, out var part, out var total) || text.Length == 0)
        {
            return Result.Fail("invalid", "ask parts are numbered n/total (total 1-8) and need text");
        }
        if (part == 1)
        {
            _partialAsks[author] = (total, new List<string>());
        }
        if (!_partialAsks.TryGetValue(author, out var partial) || partial.Total != total || partial.Parts.Count != part - 1)
        {
            _partialAsks.Remove(author);
            return Result.Fail("invalid", "ask parts arrived out of order");
        }
        partial.Parts.Add(text);
        if (part < total)
        {
            return new Result { Ok = true, Code = "partial" };
        }
        _partialAsks.Remove(author);
        var whole = string.Join(" ", partial.Parts);
        if (whole.Length > MaxText)
        {
            return Result.Fail("invalid", $"requests are limited to {MaxText} characters");
        }
        ask = new Ask { Id = _next++, Author = author, Text = whole };
        _asks.Add(ask);
        if (_asks.Count > Retained)
        {
            _asks.RemoveAt(0);
        }
        return new Result { Ok = true, Code = "asked" };
    }

    public Result Answer(int id, string author, string text)
    {
        text = Clean(text);
        if (Find(id) is not { } ask || text.Length == 0 || text.Length > 115)
        {
            return Result.Fail("invalid", "unknown request or empty/overlong answer");
        }
        ask.Answers.Add($"{author}: {text}");
        if (ask.Status == "open")
        {
            ask.Status = "answered";
        }
        return new Result { Ok = true, Code = "answered" };
    }

    // A proposal is an ordered list of command lines in the shared grammar
    // (DevEdit/DevEditCommands.gd); it replaces any earlier proposal.
    public Result ProposePart(int id, string author, string spec, string line, out bool complete)
    {
        complete = false;
        line = Clean(line);
        if (Find(id) is not { } ask || ask.Status is "applied" or "declined")
        {
            return Result.Fail("invalid", "unknown or closed request");
        }
        if (!Part(spec, out var part, out var total) || total > MaxProposal || line.Length is 0 or > 110)
        {
            return Result.Fail("invalid", "proposal lines are numbered n/total and hold one command");
        }
        var key = (id, author);
        if (part == 1)
        {
            _partialProposals[key] = new string[total];
        }
        if (!_partialProposals.TryGetValue(key, out var lines) || lines.Length != total || part > 1 && lines[part - 2] == null)
        {
            _partialProposals.Remove(key);
            return Result.Fail("invalid", "proposal lines arrived out of order");
        }
        lines[part - 1] = line;
        if (part == total)
        {
            _partialProposals.Remove(key);
            ask.Proposal = lines;
            ask.ProposedBy = author;
            ask.Status = "proposed";
            complete = true;
        }
        return new Result { Ok = true, Code = complete ? "proposed" : "partial" };
    }

    // Only the asking editor closes a request (after applying or declining).
    public Result Resolve(int id, string author, string outcome)
    {
        if (Find(id) is not { } ask || ask.Author != author || outcome is not ("applied" or "declined"))
        {
            return Result.Fail("invalid", "only the asking editor can mark a request applied or declined");
        }
        ask.Status = outcome;
        return new Result { Ok = true, Code = outcome };
    }
}
