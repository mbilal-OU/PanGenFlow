# FastANI: when to use it

FastANI is useful for rapid ANI estimation among sufficiently related prokaryotic genomes. It is not designed to force a numerical ANI value for every pair across deeply divergent taxonomic groups.

## PanGenFlow behavior

`run_fastani.sh`:

- stores all FastANI-reported pairs;
- calculates alignment fraction for reported query/reference comparisons;
- builds a symmetric visualization matrix only from observed values;
- leaves unreported pairs as `NA`;
- reports the fraction of pairwise comparisons that received estimates;
- never substitutes an arbitrary low ANI value for missing output.

## Practical interpretation

A matrix with many missing pairs often means the genome set is too divergent for FastANI to serve as a complete all-vs-all distance matrix. That is information about **method suitability**, not evidence that every missing pair has one specific identity value.

For broad phylum-level comparisons, use a method appropriate to that evolutionary scale rather than coercing FastANI output into a complete matrix.
