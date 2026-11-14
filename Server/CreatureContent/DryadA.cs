// SPDX-License-Identifier: GPL-3.0-or-later
using ModernUO.Serialization;

namespace Server.Mobiles;

// TwistedWeald.json uses DryadA and Dryada. The spawner resolves names case-insensitively.
[SerializationGenerator(0)]
public sealed partial class DryadA : MLDryad
{
    [Constructible]
    public DryadA()
    {
    }
}
