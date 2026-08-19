# PanGenFlow documentation

PanGenFlow prepares microbial genome collections for downstream comparative genomics. It focuses on **acquisition, GCA/GCF assembly-record reconciliation, metadata, genome-quality filtering, and optional close-genome relatedness checks**.

![PanGenFlow workflow](../figures/pangenflow_workflow.svg)

## Documentation map

- [Workflow and scientific scope](workflow.md)
- [FastANI: when to use it](fastani_scope.md)
- [Command cheatsheet](cheatsheet.md)

## Minimal core path

```bash
git clone https://github.com/mbilal-OU/PanGenFlow.git
cd PanGenFlow
conda env create -f environment.yml
conda activate pangenflow

bash scripts/batch_download.sh "Deinococcus" genomes/
python scripts/deduplicate_genomes.py genomes/ncbi_dataset/data genome_list_clean.txt
python scripts/extract_metadata.py genomes/ncbi_dataset/data/assembly_data_report.jsonl metadata_table.tsv
```

CheckM2 is intentionally kept in a separate environment because it carries its own machine-learning and DIAMOND dependencies.

The historical script name `deduplicate_genomes.py` is retained for compatibility, but its NCBI-specific role is more precisely described as **GCA/GCF assembly-record reconciliation**.
