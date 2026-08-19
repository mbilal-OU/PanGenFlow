# PanGenFlow command cheatsheet

## Install core tools

```bash
conda env create -f environment.yml
conda activate pangenflow
```

## Download a taxon

```bash
bash scripts/batch_download.sh "Deinococcus" genomes/
```

Large download:

```bash
bash scripts/batch_download.sh "Deinococcota" genomes/ --dehydrated --workers 12
```

Use all NCBI assembly sources:

```bash
bash scripts/batch_download.sh "Deinococcus" genomes_all/ --source all
```

## Reconcile paired GCA/GCF records

```bash
python scripts/deduplicate_genomes.py \
  genomes/ncbi_dataset/data \
  genome_list_clean.txt
```

## Extract metadata

```bash
python scripts/extract_metadata.py \
  genomes/ncbi_dataset/data/assembly_data_report.jsonl \
  metadata_table.tsv
```

RefSeq-only metadata:

```bash
python scripts/extract_metadata.py \
  genomes/ncbi_dataset/data/assembly_data_report.jsonl \
  metadata_refseq.tsv \
  --source RefSeq
```

## CheckM2

```bash
conda activate checkm2
bash scripts/run_checkm2.sh \
  genome_list_clean.txt \
  checkm2_results/ \
  "$CHECKM2DB" \
  8 95 5
```

## Optional FastANI

```bash
conda activate pangenflow
bash scripts/run_fastani.sh \
  checkm2_results/genome_list_qc_passed.txt \
  fastani_results/ \
  8
```
