#!/usr/bin/env python3
"""Select one genome FASTA per paired GenBank/RefSeq assembly family.

PanGenFlow prefers RefSeq (GCF_) when a paired RefSeq assembly exists. Pairing is
performed on the shared numeric assembly identifier while ignoring the GCA/GCF
prefix and accession version; the highest version available for the preferred
source is retained.

Usage:
    python3 deduplicate_genomes.py <ncbi_dataset/data> [output_list.txt]
"""

from __future__ import annotations

import argparse
import re
from collections import defaultdict
from pathlib import Path

ACCESSION_RE = re.compile(r"^(GC[AF])_(\d+)\.(\d+)$")


def parse_accession(name: str):
    match = ACCESSION_RE.match(name)
    if not match:
        return None
    prefix, numeric, version = match.groups()
    return prefix, numeric, int(version)


def find_fasta(accession_dir: Path) -> Path | None:
    candidates = sorted(
        p for p in accession_dir.iterdir()
        if p.is_file() and (p.name.endswith(".fna") or p.name.endswith(".fna.gz"))
    )
    return candidates[0] if candidates else None


def choose_accessions(data_dir: Path):
    grouped = defaultdict(list)
    ignored = []

    for path in sorted(data_dir.iterdir()):
        if not path.is_dir():
            continue
        parsed = parse_accession(path.name)
        if parsed is None:
            if path.name.startswith(("GCA_", "GCF_")):
                ignored.append(path.name)
            continue
        prefix, numeric, version = parsed
        grouped[numeric].append((prefix, version, path))

    selected = []
    for numeric, records in sorted(grouped.items()):
        gcf = [r for r in records if r[0] == "GCF"]
        gca = [r for r in records if r[0] == "GCA"]
        pool = gcf if gcf else gca
        selected.append(max(pool, key=lambda r: r[1]))

    return selected, ignored


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("data_directory", type=Path)
    parser.add_argument("output_list", nargs="?", type=Path, default=Path("genome_list_clean.txt"))
    args = parser.parse_args()

    data_dir = args.data_directory
    if not data_dir.is_dir():
        parser.error(f"data directory not found: {data_dir}")

    selected, ignored = choose_accessions(data_dir)
    found = []
    missing = []
    gcf_count = 0
    gca_count = 0

    for prefix, version, accession_dir in selected:
        if prefix == "GCF":
            gcf_count += 1
        else:
            gca_count += 1
        fasta = find_fasta(accession_dir)
        if fasta is None:
            missing.append(accession_dir.name)
        else:
            found.append(fasta.resolve())

    args.output_list.parent.mkdir(parents=True, exist_ok=True)
    with args.output_list.open("w", encoding="utf-8") as handle:
        for path in found:
            handle.write(f"{path}\n")

    print(f"Data directory       : {data_dir}")
    print(f"Assembly families    : {len(selected)}")
    print(f"Selected RefSeq GCF  : {gcf_count}")
    print(f"Selected GenBank GCA : {gca_count}")
    print(f"Genome FASTAs written: {len(found)}")
    print(f"Missing FASTA        : {len(missing)}")
    print(f"Output               : {args.output_list}")

    if ignored:
        print(f"Ignored non-standard accession folders: {len(ignored)}")
    if missing:
        print("Accessions without a genome FASTA:")
        for accession in missing:
            print(f"  {accession}")

    return 0 if found else 1


if __name__ == "__main__":
    raise SystemExit(main())
