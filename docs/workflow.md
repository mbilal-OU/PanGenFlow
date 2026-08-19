# Workflow and scientific scope

PanGenFlow is a **curation toolkit**, not an end-to-end biological analysis pipeline. Its core path is intentionally limited to creating a defensible microbial genome cohort.

## Acquire

`batch_download.sh` wraps the NCBI Datasets CLI and exposes the filters most useful for microbial comparative genomics: taxon/taxid, assembly source, assembly level, included file types, and dehydrated downloads.

For large packages, use `--dehydrated`. The script unpacks the metadata-only package and then calls `datasets rehydrate`.

## Reconcile paired GCA/GCF records

`deduplicate_genomes.py` prevents paired GenBank/RefSeq representations of the same assembly family from being counted twice. It prefers RefSeq (`GCF_`) if present and otherwise keeps the GenBank (`GCA_`) assembly.

This is **assembly-record reconciliation**, not strain dereplication. Two genuinely different isolates remain separate even if they are nearly identical biologically.

The existing filename is kept for backward compatibility because it is already part of the public command interface.

## Capture metadata

`extract_metadata.py` reads `assembly_data_report.jsonl` using the current NCBI assembly-report structure and extracts fields actually present in that report.

PanGenFlow does not infer genus/family/order/phylum from organism strings. If full lineage is required, retrieve NCBI taxonomy data separately.

## Apply CheckM2 quality filters

`run_checkm2.sh` applies user-defined completeness and contamination thresholds and writes separate passed/failed genome lists.

The script stages genomes with symlinks rather than copying the whole dataset into a second directory. `input_mapping.tsv` preserves the relationship between CheckM2 labels and original genome paths.

## Optional FastANI branch

FastANI is intentionally outside the required core path. Use it when the input genomes are expected to be sufficiently related for nucleotide-level ANI estimation.

Unreported pairs remain missing; they are not assigned arbitrary ANI values.

See [FastANI: when to use it](fastani_scope.md).

## Handoff

The primary PanGenFlow deliverable is an explicit genome list such as:

```text
checkm2_results/genome_list_qc_passed.txt
```

That list can feed any downstream workflow. PanPhyloFlow is one optional destination for microbial pangenomics and core-genome phylogenomics, but it is not required.
