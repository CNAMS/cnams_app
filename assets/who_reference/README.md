# WHO reference tables

`tables.json` holds the WHO LMS coefficients the on-device z-score engine uses.
It is loaded by [reference_loader.dart](../../lib/core/reference/reference_loader.dart)
and parsed into the pure-Dart `ReferenceTables` the engine consumes.

## Status

`tables.json` currently ships **empty on purpose**. With no coefficients the
engine cannot compute a z-score, so every child is reported as `indeterminate` —
the correct fail-safe. The official WHO tables must be dropped in before
**Gate G2** (engine validated against WHO Anthro).

> These coefficients are published data from the WHO Child Growth Standards; they
> are not reproduced here from memory. Generate `tables.json` from the official
> WHO source (see below) rather than hand-typing values.

## Format

```json
{
  "source": "…",
  "note": "…",
  "tables": [
    {
      "indicator": "weightForAge",
      "sex": "male",
      "points": [
        { "x": 0, "l": 0.3487, "m": 3.3464, "s": 0.14602 }
      ]
    }
  ]
}
```

- `indicator` — one of `weightForAge`, `lengthOrHeightForAge`, `weightForLength`,
  `weightForHeight`, `muacForAge`.
- `sex` — `male` or `female`.
- `x` — the lookup key: **age in days** for `*ForAge` indicators, **stature in cm**
  for `weightForLength` / `weightForHeight`.
- `l`, `m`, `s` — the LMS parameters. `m` (the median) is in the indicator's
  natural unit: **kg** for weight, **cm** for length/height and MUAC.

Points may be listed in any order; the loader sorts them by `x`. Lookups
interpolate L/M/S linearly between points and return "no result" outside the
tabulated range.

## Generating the file

The WHO tables are distributed as text/Excel files (per indicator and sex),
tabulated by day of age or by length/height. Convert them to the structure above
— one `tables[]` entry per indicator+sex, each `points[]` entry one row of the
source table — keeping units as noted. Keep a note of the exact WHO source
version in `source` for auditability.
