# Contributing to PanGenFlow

Contributions are welcome, especially fixes that improve reproducibility, current NCBI Datasets compatibility, genome-quality handling, tests, or documentation.

## Before opening a pull request

1. Create a focused branch.
2. Keep PanGenFlow within scope: genome acquisition, assembly harmonization, metadata, QC, and related preparation utilities.
3. Do not add downstream pangenome reconstruction or phylogeny here; those belong in downstream tools such as PanPhyloFlow.
4. Run:

```bash
python -m py_compile scripts/*.py
for script in scripts/*.sh; do bash -n "$script"; done
pytest -q
```

## Scientific changes

Changes to thresholds, genome-quality rules, ANI interpretation, or metadata semantics should explain the biological rationale and avoid converting missing/unsupported measurements into invented values.

## External tools

PanGenFlow wraps external bioinformatics tools rather than vendoring them. Keep version-specific or current CLI assumptions documented and prefer primary project documentation when updating commands.
