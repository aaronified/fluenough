# ADR-0003: GPL-3.0 with an App Store Distribution Exception

- **Status:** Accepted
- **Date:** 2026-09-19

## Context

Three goals, stated in priority order:

1. **Nobody may close a fork.** Derivatives must stay open.
2. **Nobody should profit from selling it**, though donations for genuine
   added value are fine.
3. **It must be distributable through both the Play Store and the App Store.**

## Decision

Licence under **GPL-3.0 plus an additional permission under section 7**
permitting distribution through app stores whose terms would otherwise
conflict. The exception text is in [LICENSE-EXCEPTION.md](../../LICENSE-EXCEPTION.md).

## Reasoning

**Goal 1 requires strong copyleft.** GPL-3.0 delivers it: any distributed
derivative must be released under GPL-3.0 in full. MPL-2.0 was considered and
rejected as too weak — its copyleft is per *file*, so a fork can combine
Fluenough's files with proprietary code and ship a largely closed product.

**Goal 2 cannot be achieved by any open source licence, and is not attempted.**
The right to sell copies is a defining requirement of both the Open Source
Definition and the Free Software Definition; GPL-3.0 §4 states it explicitly.
A licence forbidding sale would not be open source, would be rejected by
F-Droid, and would deter contributors.

Copyleft achieves the *practical* effect through a different mechanism: anyone
may sell Fluenough, but every purchaser immediately receives the source and the
right to redistribute it freely. A seller cannot stop their own customers from
giving it away. The commercial value of selling freely-redistributable copies
collapses toward zero. This is by design, not a loophole.

Non-commercial licences (PolyForm Noncommercial, Prosperity) were considered
and rejected: not open source, rejected by F-Droid, and "commercial" is
ambiguous to enforce.

**Goal 3 requires the exception.** GPL-3.0 §§7 and 10 forbid "further
restrictions"; Apple's App Store terms impose device limits and DRM that
qualify. GNU Go was removed from the App Store in 2010 over exactly this, and
VLC had to relicense to ship on iOS. The Play Store does not have this problem
— it is specific to Apple.

The section 7 additional permission is an established remedy for this, used by
other GPL/AGPL mobile projects. It waives *only* the distribution-channel
conflict and leaves every copyleft obligation intact.

**AGPL-3.0 was considered and rejected.** Its network clause targets the SaaS
loophole, which cannot trigger for an offline mobile app, so it would add
contributor friction for a protection that never applies.

## Consequences

Forks must stay open. Selling is legal but commercially pointless. The app can
ship on F-Droid, the Play Store and the App Store.

**No CLA is required.** The exception is part of the project licence from the
first commit, so all contributions are made under GPL-3.0-with-exception
automatically. This matters for a project whose deck content arrives as pull
requests.

The licence cannot be changed later without the agreement of every contributor.
This is accepted deliberately.

The name "Fluenough" is not licensed. Copyleft permits anyone to fork the code;
trademark is the separate instrument that stops a fork passing itself off as
the original.
