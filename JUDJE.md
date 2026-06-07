# JUDJE.md

English judging criteria for thon-judge.

## Weights

| Area | Weight |
| --- | ---: |
| Product | 35 |
| Creativity | 20 |
| Harness | 25 |
| Lobster | 20 |

## Product - 35

Reward a working, inspectable product with clear user value, a coherent README, and evidence that the submission can be tried or evaluated.

## Creativity/Originality - 20

Reward niche insight, low competition, distinctive framing, and a product direction that is not a generic clone.

## Harness Understanding - 25

Reward evidence-backed harness engineering:

- Predicate-based acceptance criteria.
- Falsifiable checks.
- Deterministic reproduction.
- Verification ladder from static checks to real execution.
- Clean-state causality tests.
- Side-effect awareness and cleanup.
- Root-cause discipline.
- Hands-off autonomy.
- Control surfaces and lifecycle hooks.
- Drift, early-stop, data-destruction, and budget-burn prevention.
- File/git-backed durable state.
- Cost-aware QA ordering.

## Lobster Count - 20

Start from 20 points and subtract 4 points per lobster usage. The result is floored at 0:

```text
max(0, 20 - 4 * lobster_count)
```

