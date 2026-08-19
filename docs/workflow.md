# Workflow and scientific scope

## 1. Genome acquisition

`batch_download.sh` wraps the NCBI Datasets CLI and exposes the filters most useful for microbial comparative genomics: taxon/taxid, assembly source, assembly level, included file types, and dehydrated downloads.

For large packages, use `--dehydrated`. The script unpacks the metadata-only package and then calls `datasets rehydrate`.

## 2. GCA/GCF harmonization

`deduplicate_genomes.py` prevents paired GenBank/RefSeq representations of the same assembly family from being counted twice. It prefers RefSeq (`GCF_`) if present and otherwise keeps the GenBank (`GCA_`) assembly.

This is **assembly-source harmonization**, not strain dereplication. Two genuinely different isolates remain separate even if they are nearly identical biologically.

## 3. Metadata extraction

`extract_metadata.py` reads `assembly_data_report.jsonl` using the current NCBI assembly-report structure. It extracts stable fields that are actually present in that report.

PanGenFlow does not infer genus/family/order/phylum from organism strings. If full lineage is required, retrieve NCBI taxonomy data separately.

## 4. CheckM2 filtering

`run_checkm2.sh` applies user-defined completeness and contamination thresholds and writes separate passed/failed genome lists.

The script stages genomes with symlinks rather than copying the whole dataset into a second directory. `input_mapping.tsv` preserves the relationship between CheckM2 labels and original genome paths.

## 5. Optional FastANI

FastANI is intentionally outside the required core path. Use it when the input genomes are expected to be sufficiently related for nucleotide-level ANI estimation.

See [FastANI: when to use it](fastani_scope.md).

## 6. Downstream analysis

The primary PanGenFlow deliverable is an explicit genome list such as:

```text
checkm2_results/genome_list_qc_passed.txt
```

That list can feed any downstream workflow. For microbial pangenomics and core-genome phylogeny, PanPhyloFlow is one optional companion.
