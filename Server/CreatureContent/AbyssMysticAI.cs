// SPDX-License-Identifier: GPL-3.0-or-later
using Server.Spells;
using Server.Spells.Mysticism;

namespace Server.Mobiles;

internal sealed class AbyssMysticAI(BaseCreature creature) : MageAI(creature)
{
    private bool CanMixMagery => !Mobile.Controlled && Mobile.Skills[SkillName.Magery].Base >= 20.0;

    public override bool Think()
    {
        if (Mobile.Target is ISpellTarget<IPoint3D> { Spell: HailStormSpell or NetherCycloneSpell } &&
            Mobile.Target is { } cursor && Mobile.Combatant is { } target &&
            Mobile.InRange(target, cursor.Range) && Mobile.CanSee(target) && Mobile.InLOS(target))
        {
            cursor.Invoke(Mobile, target);
            return true;
        }

        return base.Think();
    }

    public override Spell? ChooseSpell(Mobile target)
    {
        if (!Core.SA || CanMixMagery && Utility.RandomBool())
        {
            return base.ChooseSpell(target);
        }

        var mana = Mobile.Mana;
        var heal = new CleansingWindsSpell(Mobile, null);
        if (Mobile.Hits < Mobile.HitsMax / 2 && mana >= heal.GetMana())
        {
            return heal;
        }

        var curse = new SpellPlagueSpell(Mobile);
        if (mana >= curse.GetMana() && Utility.Random(6) == 0)
        {
            return curse;
        }

        Spell attack = Utility.Random(mana >= 50 ? 4 : mana >= 20 ? 2 : 1) switch
        {
            1 => new BombardSpell(Mobile, null),
            2 => new HailStormSpell(Mobile),
            3 => new NetherCycloneSpell(Mobile),
            _ => new EagleStrikeSpell(Mobile)
        };
        if (mana < attack.GetMana())
        {
            attack = new EagleStrikeSpell(Mobile);
        }

        return mana >= attack.GetMana() ? attack : null;
    }
}
