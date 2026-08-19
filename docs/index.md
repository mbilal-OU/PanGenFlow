# PanGenFlow documentation

PanGenFlow prepares microbial genome collections for downstream comparative genomics. It focuses on **acquisition, assembly harmonization, metadata, genome-quality filtering, and optional close-genome relatedness checks**.

![PanGenFlow workflow](https://raw.githubusercontent.com/mbilal-OU/PanGenFlow/main/figures/pangenflow_workflow.svg)

## Learning path

1. [Workflow and scientific scope](workflow.md)
2. [FastANI: when to use it](fastani_scope.md)
3. [Command cheatsheet](cheatsheet.md)

## Start here

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
