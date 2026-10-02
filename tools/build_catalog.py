#!/usr/bin/env python3
"""Build the bundled food catalog from the USDA FoodData Central SR Legacy CSV release.

Usage:
    python3 tools/build_catalog.py <path-to-unzipped-sr-legacy-csv-dir> [output.sqlite]

Download the source from https://fdc.nal.usda.gov/download-datasets
("SR Legacy", CSV, April 2018). USDA FoodData Central data is public domain (CC0).

The output keeps raw USDA nutrient IDs and units. Mapping USDA nutrients onto the app's
canonical nutrient registry (including energy selection and unit conversions) happens in
Swift (`NutrientRegistry`), so the rules live in one tested place.
"""

import csv
import os
import re
import sqlite3
import sys
from datetime import datetime, timezone

SOURCE_NAME = "USDA FoodData Central"
SOURCE_DATA_TYPE = "SR Legacy"
SOURCE_VERSION = "2018-04"

# Every USDA nutrient ID the Swift registry knows how to map. Others are dropped to keep
# the bundle small. Keep in sync with NutrientRegistry.swift.
KEPT_NUTRIENTS = {
    # energy (alternative expressions; the app selects exactly one)
    1008, 2047, 2048, 1062,
    # macros and composition
    1003, 1004, 1005, 1050, 1085, 1079, 2000, 1063, 1235, 1258, 1257, 1292, 1293,
    1253, 1051, 1018, 1057,
    # vitamins
    1106, 1104, 1162, 1114, 1110, 1109, 1185, 1165, 1166, 1167, 1175, 1190, 1177,
    1186, 1178, 1170, 1176, 1180,
    # minerals
    1087, 1089, 1090, 1091, 1092, 1093, 1095, 1098, 1101, 1103, 1100, 1099,
    # carotenoids
    1107, 1122, 1123,
    # fatty acids
    1269, 1270, 1404, 1278, 1272, 1280,
    # amino acids
    1210, 1211, 1212, 1213, 1214, 1215, 1216, 1217, 1218, 1219, 1220, 1221, 1222,
    1223, 1224, 1225, 1226, 1227,
}

PREPARATION_TERMS = [
    "raw", "cooked", "boiled", "baked", "roasted", "fried", "pan-fried", "deep-fried",
    "steamed", "grilled", "broiled", "braised", "stewed", "simmered", "microwaved",
    "poached", "scrambled", "drained", "canned", "frozen", "dried", "dehydrated",
    "prepared", "unprepared", "toasted", "smoked", "cured", "fresh",
]
PREPARATION_PATTERN = re.compile(
    r"\b(" + "|".join(re.escape(t) for t in PREPARATION_TERMS) + r")\b", re.IGNORECASE
)


def read_csv(directory, name):
    with open(os.path.join(directory, name), newline="", encoding="utf-8") as handle:
        yield from csv.DictReader(handle)


def preparation_of(description):
    found = []
    for match in PREPARATION_PATTERN.finditer(description):
        term = match.group(1).lower()
        if term not in found:
            found.append(term)
    return ", ".join(found) if found else None


def build(source_dir, output_path):
    if os.path.exists(output_path):
        os.remove(output_path)
    db = sqlite3.connect(output_path)
    db.executescript(
        """
        PRAGMA page_size = 4096;
        CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT NOT NULL);
        CREATE TABLE nutrient (
            id INTEGER PRIMARY KEY,
            name TEXT NOT NULL,
            unit TEXT NOT NULL
        );
        CREATE TABLE derivation (
            id INTEGER PRIMARY KEY,
            code TEXT NOT NULL,
            description TEXT NOT NULL
        );
        CREATE TABLE food (
            fdc_id INTEGER PRIMARY KEY,
            description TEXT NOT NULL,
            category TEXT,
            preparation TEXT,
            ndb_number TEXT,
            publication_date TEXT
        );
        CREATE TABLE food_nutrient (
            fdc_id INTEGER NOT NULL,
            nutrient_id INTEGER NOT NULL,
            amount REAL NOT NULL,
            derivation_id INTEGER,
            PRIMARY KEY (fdc_id, nutrient_id)
        ) WITHOUT ROWID;
        CREATE TABLE food_portion (
            fdc_id INTEGER NOT NULL,
            seq INTEGER NOT NULL,
            amount REAL NOT NULL,
            description TEXT NOT NULL,
            gram_weight REAL NOT NULL,
            PRIMARY KEY (fdc_id, seq)
        ) WITHOUT ROWID;
        CREATE VIRTUAL TABLE food_search USING fts5(
            description, content='food', content_rowid='fdc_id',
            tokenize = "unicode61 remove_diacritics 2"
        );
        """
    )

    categories = {row["id"]: row["description"] for row in read_csv(source_dir, "food_category.csv")}
    ndb_numbers = {row["fdc_id"]: row["NDB_number"] for row in read_csv(source_dir, "sr_legacy_food.csv")}

    nutrient_rows = [
        (int(row["id"]), row["name"], row["unit_name"])
        for row in read_csv(source_dir, "nutrient.csv")
        if int(row["id"]) in KEPT_NUTRIENTS
    ]
    db.executemany("INSERT INTO nutrient VALUES (?, ?, ?)", nutrient_rows)

    derivation_rows = [
        (int(row["id"]), row["code"], " ".join(row["description"].split()))
        for row in read_csv(source_dir, "food_nutrient_derivation.csv")
    ]
    db.executemany("INSERT INTO derivation VALUES (?, ?, ?)", derivation_rows)

    food_rows = []
    for row in read_csv(source_dir, "food.csv"):
        if row["data_type"] != "sr_legacy_food":
            continue
        description = row["description"].strip()
        food_rows.append(
            (
                int(row["fdc_id"]),
                description,
                categories.get(row["food_category_id"]),
                preparation_of(description),
                ndb_numbers.get(row["fdc_id"]),
                row["publication_date"],
            )
        )
    db.executemany("INSERT INTO food VALUES (?, ?, ?, ?, ?, ?)", food_rows)
    food_ids = {row[0] for row in food_rows}

    nutrient_values = []
    for row in read_csv(source_dir, "food_nutrient.csv"):
        fdc_id = int(row["fdc_id"])
        nutrient_id = int(row["nutrient_id"])
        if fdc_id not in food_ids or nutrient_id not in KEPT_NUTRIENTS or row["amount"] == "":
            continue
        amount = float(row["amount"])
        if amount < 0:
            continue
        derivation = int(row["derivation_id"]) if row["derivation_id"] else None
        nutrient_values.append((fdc_id, nutrient_id, amount, derivation))
    db.executemany("INSERT OR REPLACE INTO food_nutrient VALUES (?, ?, ?, ?)", nutrient_values)

    portion_rows = []
    for row in read_csv(source_dir, "food_portion.csv"):
        fdc_id = int(row["fdc_id"])
        if fdc_id not in food_ids or not row["gram_weight"]:
            continue
        amount = float(row["amount"]) if row["amount"] else 1.0
        gram_weight = float(row["gram_weight"])
        description = " ".join(filter(None, [row["portion_description"].strip(), row["modifier"].strip()]))
        if amount <= 0 or gram_weight <= 0 or not description:
            continue
        portion_rows.append((fdc_id, int(row["seq_num"] or 0), amount, description, gram_weight))
    db.executemany("INSERT OR REPLACE INTO food_portion VALUES (?, ?, ?, ?, ?)", portion_rows)

    db.execute("INSERT INTO food_search(food_search) VALUES ('rebuild')")
    db.executemany(
        "INSERT INTO meta VALUES (?, ?)",
        [
            ("schema_version", "1"),
            ("source", SOURCE_NAME),
            ("source_data_type", SOURCE_DATA_TYPE),
            ("source_version", SOURCE_VERSION),
            ("license", "Public domain (CC0 1.0), USDA FoodData Central"),
            ("built_at", datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")),
            ("food_count", str(len(food_rows))),
        ],
    )
    db.commit()
    db.execute("INSERT INTO food_search(food_search) VALUES ('optimize')")
    db.commit()
    db.execute("VACUUM")
    db.close()
    print(
        f"Wrote {output_path}: {len(food_rows)} foods, {len(nutrient_values)} nutrient values, "
        f"{len(portion_rows)} portions, {os.path.getsize(output_path) / 1_000_000:.1f} MB"
    )


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(2)
    source_dir = sys.argv[1]
    default_output = os.path.join(
        os.path.dirname(os.path.abspath(__file__)),
        "..", "Packages", "InstalogCore", "Sources", "InstalogCore", "Resources", "catalog.sqlite",
    )
    output_path = os.path.abspath(sys.argv[2] if len(sys.argv) > 2 else default_output)
    build(source_dir, output_path)


if __name__ == "__main__":
    main()
