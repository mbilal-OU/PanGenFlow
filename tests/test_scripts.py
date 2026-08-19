from importlib.util import module_from_spec, spec_from_file_location
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def load_module(name, path):
    spec = spec_from_file_location(name, path)
    module = module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_deduplicate_prefers_gcf_and_highest_version(tmp_path):
    mod = load_module("dedup", ROOT / "scripts" / "deduplicate_genomes.py")

    for accession in ["GCA_000001405.29", "GCF_000001405.39", "GCF_000001405.40", "GCA_000999999.1"]:
        d = tmp_path / accession
        d.mkdir()
        (d / f"{accession}_genomic.fna").write_text(">x\nATGC\n")

    selected, ignored = mod.choose_accessions(tmp_path)
    names = [record[2].name for record in selected]

    assert ignored == []
    assert "GCF_000001405.40" in names
    assert "GCF_000001405.39" not in names
    assert "GCA_000001405.29" not in names
    assert "GCA_000999999.1" in names


def test_metadata_parser_current_ncbi_schema():
    mod = load_module("metadata", ROOT / "scripts" / "extract_metadata.py")
    record = {
        "accession": "GCF_000001405.40",
        "currentAccession": "GCF_000001405.40",
        "pairedAccession": "GCA_000001405.29",
        "sourceDatabase": "SOURCE_DATABASE_REFSEQ",
        "organism": {
            "organismName": "Example bacterium",
            "taxId": 123,
            "infraspecificNames": {"strain": "X1"},
        },
        "assemblyInfo": {
            "assemblyName": "ASM1",
            "assemblyLevel": "Complete Genome",
            "assemblyStatus": "current",
            "refseqCategory": "reference genome",
            "bioprojectAccession": "PRJNA1",
            "releaseDate": "2026-01-01",
        },
        "assemblyStats": {
            "totalSequenceLength": "5000000",
            "gcPercent": 55.5,
            "numberOfContigs": 1,
            "contigN50": 5000000,
            "numberOfScaffolds": 1,
            "scaffoldN50": 5000000,
        },
        "annotationInfo": {"stats": {"geneCounts": {"total": 4500, "proteinCoding": 4300}}},
        "checkmInfo": {"completeness": 99.5, "contamination": 0.2},
        "averageNucleotideIdentity": {"taxonomyCheckStatus": "ok", "matchStatus": "derived-species-match"},
    }

    row = mod.record_to_row(record)
    assert row["source_database"] == "RefSeq"
    assert row["paired_accession"] == "GCA_000001405.29"
    assert row["gene_count"] == 4500
    assert row["protein_count"] == 4300
    assert row["ncbi_checkm_completeness"] == 99.5
    assert row["ncbi_ani_check_status"] == "ok"
