#!/usr/bin/env python3
"""
Enterprise Authentic Google Maps Scraper Pipeline for Riyadh Corporate Offices
Supplying Cleaners, Pantry Staff, and Tea Boys.

Architectural Guarantees:
- ZERO synthetic leads: Absolutely no Faker, random lists, or LLM-generated business names.
- Zero duplication: Once a company/number is scraped, it must never reappear across daily runs.
- 100% authentic Google Maps profiles only.
- Strict "Zero Data over Fake Data" Guardrail.
"""

import os
import sys
import json
import re
import hashlib
from datetime import datetime, timezone
import requests
from bs4 import BeautifulSoup

# Reconfigure stdout to UTF-8 if supported
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

DEFAULT_QUERIES = [
    {
        "query": "corporate office in KAFD",
        "hub": "KAFD Phase 1 & 2",
        "cluster_group": "Core Corporate Hubs",
        "intent_base": 95,
    },
    {
        "query": "business offices in Al Olaya",
        "hub": "Al Olaya",
        "cluster_group": "Core Corporate Hubs",
        "intent_base": 89,
    },
    {
        "query": "consulting company in Al Narjis",
        "hub": "Al Narjis Commercial",
        "cluster_group": "Hotspot Boom Strip",
        "intent_base": 90,
    },
    {
        "query": "head office in Roshn Front",
        "hub": "Roshn Front Business Zone",
        "cluster_group": "Hotspot Boom Strip",
        "intent_base": 92,
    },
    {
        "query": "corporate towers King Salman Rd",
        "hub": "King Salman Road Business Strip",
        "cluster_group": "Hotspot Boom Strip",
        "intent_base": 91,
    },
]

SAUDI_MOBILE_REGEX = re.compile(r"^(?:\+966|00966|0)?(5[0-9]{8})$")

def normalize_saudi_mobile(raw_phone: str) -> str | None:
    r"""
    Accept ONLY numbers matching regex: r"^(?:\+966|00966|0)?5[0-9]{8}$"
    Convert strictly to +9665xxxxxxxx.
    Discard all landlines (011), unified lines (9200, 800), and missing numbers.
    """
    if not raw_phone:
        return None
    clean = re.sub(r"[\s\-\(\)\.]", "", str(raw_phone).strip())
    m = SAUDI_MOBILE_REGEX.match(clean)
    if m:
        return f"+966{m.group(1)}"
    return None

def normalize_company_name(name: str) -> str:
    """Normalize Arabic and English company names for deduplication."""
    if not name:
        return ""
    clean = name.strip().lower()
    clean = re.sub(r"^(?:شركة|مؤسسة|مكتب|فرع)\s+", "", clean)
    clean = re.sub(r"\b(?:co|company|ltd|llc|inc|est|corporation|corp|branch|group)\b", "", clean, flags=re.IGNORECASE)
    clean = re.sub(r"[^\w\s\u0600-\u06FF]", " ", clean)
    return re.sub(r"\s+", " ", clean).strip()

def generate_dedup_hash(normalized_phone: str, place_id: str) -> str:
    """
    Deduplication Key: Generate a unique composite SHA-256 hash from:
    hash_key = SHA256(normalized_phone + "_" + place_id)
    """
    raw_key = f"{normalized_phone.strip()}_{place_id.strip()}"
    return hashlib.sha256(raw_key.encode("utf-8")).hexdigest()

def extract_phone_from_place(p1: list) -> str | None:
    """Extract primary business phone from the Place details array."""
    try:
        # Index 178 contains the official phone metadata structure
        if len(p1) > 178 and p1[178] and isinstance(p1[178], list) and len(p1[178]) > 0:
            item = p1[178][0]
            if isinstance(item, list):
                if len(item) > 3 and item[3]:
                    return str(item[3])
                if len(item) > 0 and item[0]:
                    return str(item[0])
    except Exception:
        pass

    # Fallback search for phone numbers inside p1 metadata
    def deep_find_phone(obj):
        if isinstance(obj, str):
            if re.search(r"(?:\+966\s*5\d|05\d|\+966\s*11|011|9200|800)", obj):
                return obj
        elif isinstance(obj, list):
            for sub in obj:
                res = deep_find_phone(sub)
                if res:
                    return res
        elif isinstance(obj, dict):
            for v in obj.values():
                res = deep_find_phone(v)
                if res:
                    return res
        return None

    return deep_find_phone(p1)

def query_google_maps_live(search_query: str, session: requests.Session) -> list[dict]:
    """
    Authentic Google Maps Live Extraction (Real Places Only).
    Extracts strictly from real Google Place records:
    - place_id: Authentic Google Place ID.
    - company_name: Verbatim business title as displayed on Google Maps.
    - address: Real street address in Riyadh.
    - google_maps_url: Direct playable link (https://maps.google.com/?q=place_id:PLACE_ID).
    - phone: Primary business phone.
    - lat, lng: Geographical coordinates.
    """
    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
        "Accept-Language": "en-US,en;q=0.9,ar;q=0.8",
    }
    url = f"https://www.google.com/maps/search/{requests.utils.quote(search_query)}"
    records = []

    try:
        r = session.get(url, headers=headers, timeout=20)
        if r.status_code != 200:
            print(f"  [HTTP {r.status_code}] Google Maps initial search failed for query: {search_query}")
            return []

        soup = BeautifulSoup(r.text, "html.parser")
        link = soup.find("link", href=re.compile(r"/search\?tbm=map"))
        if not link:
            print(f"  [Warning] No Google Maps search RPC endpoint found in HTML for: {search_query}")
            return []

        full_url = "https://www.google.com" + link["href"]
        r2 = session.get(full_url, headers=headers, timeout=20)
        if r2.status_code != 200:
            print(f"  [HTTP {r2.status_code}] Google Maps data fetch failed for query: {search_query}")
            return []

        text = r2.text
        if text.startswith(")]}'"):
            text = text[4:].strip()

        data = json.loads(text)
        places = data[64] if len(data) > 64 and isinstance(data[64], list) else []

        for p in places:
            if not isinstance(p, list) or len(p) < 2 or not isinstance(p[1], list):
                continue
            p1 = p[1]

            # 1. Company Name (Verbatim title)
            company_name = p1[11] if len(p1) > 11 and isinstance(p1[11], str) else None
            if not company_name:
                continue

            # 2. Authentic Google Place ID
            place_id = p1[78] if len(p1) > 78 and isinstance(p1[78], str) and p1[78].startswith("ChIJ") else None
            if not place_id and len(p1) > 227 and isinstance(p1[227], list) and len(p1[227]) > 0:
                sub227 = p1[227][0]
                if isinstance(sub227, list) and len(sub227) > 4 and isinstance(sub227[4], str) and sub227[4].startswith("ChIJ"):
                    place_id = sub227[4]

            if not place_id:
                # Must be an authentic Google Place record with authentic place_id
                continue

            # 3. Address in Riyadh
            address = p1[18] if len(p1) > 18 and isinstance(p1[18], str) else (
                p1[39] if len(p1) > 39 and isinstance(p1[39], str) else ""
            )

            # 4. Direct Playable Google Maps URL
            google_maps_url = f"https://maps.google.com/?q=place_id:{place_id}"

            # 5. Primary business phone
            raw_phone = extract_phone_from_place(p1)

            # 6. Latitude & Longitude
            lat, lng = None, None
            if len(p1) > 9 and isinstance(p1[9], list) and len(p1[9]) >= 4:
                lat = p1[9][2]
                lng = p1[9][3]

            records.append({
                "place_id": place_id,
                "company_name": company_name.strip(),
                "address": address.strip(),
                "google_maps_url": google_maps_url,
                "raw_phone": raw_phone,
                "lat": lat,
                "lng": lng,
            })

    except Exception as e:
        print(f"  [Error] Live extraction exception for '{search_query}': {e}")

    return records

def load_blacklist(blacklist_path: str) -> set[str]:
    blacklisted = set()
    if os.path.exists(blacklist_path):
        try:
            with open(blacklist_path, "r", encoding="utf-8") as f:
                data = json.load(f)
                if isinstance(data, list):
                    for item in data:
                        p = item.get("phone") if isinstance(item, dict) else str(item)
                        norm = normalize_saudi_mobile(p)
                        if norm:
                            blacklisted.add(norm)
                        elif p:
                            clean_digits = re.sub(r"\D", "", str(p))
                            if clean_digits:
                                blacklisted.add(clean_digits)
                elif isinstance(data, dict):
                    for k in data.keys():
                        norm = normalize_saudi_mobile(k)
                        if norm:
                            blacklisted.add(norm)
                        else:
                            clean_digits = re.sub(r"\D", "", str(k))
                            if clean_digits:
                                blacklisted.add(clean_digits)
        except Exception as e:
            print(f"Warning: Failed to parse blacklist file: {e}")
    return blacklisted

def load_lead_registry(registry_path: str) -> dict[str, dict]:
    """
    Loads persistent deduplication registry:
    { hash_key: { "hash_key": ..., "place_id": ..., "phone": ..., "company_name": ..., "date_added": ... } }
    """
    if os.path.exists(registry_path):
        try:
            with open(registry_path, "r", encoding="utf-8") as f:
                data = json.load(f)
                if isinstance(data, dict):
                    return data
                elif isinstance(data, list):
                    reg = {}
                    for item in data:
                        hk = item.get("hash_key")
                        if hk:
                            reg[hk] = item
                    return reg
        except Exception as e:
            print(f"Warning: Failed to parse lead registry: {e}")
    return {}

def save_lead_registry(registry_path: str, registry: dict[str, dict]):
    os.makedirs(os.path.dirname(registry_path) or ".", exist_ok=True)
    with open(registry_path, "w", encoding="utf-8") as f:
        json.dump(registry, f, indent=2, ensure_ascii=False)

def run_pipeline(
    output_path: str = "data/scraped_leads.json",
    registry_path: str = "data/lead_registry.json",
    blacklist_path: str = "data/blacklist_contacts.json",
    target_queries: list[dict] | None = None,
) -> list[dict]:
    """
    Executes the 100% authentic Google Maps scraping pipeline with SHA-256 persistent deduplication.
    Strictly adheres to: Zero synthetic leads, Zero duplication, Zero Data over Fake Data.
    """
    today_str = datetime.now(timezone.utc).date().isoformat()
    now_iso = datetime.now(timezone.utc).isoformat()
    print(f"[{now_iso}] Starting Authentic Google Maps Live Pipeline for Riyadh Hotspots...")

    queries = target_queries or DEFAULT_QUERIES
    blacklisted = load_blacklist(blacklist_path)
    registry = load_lead_registry(registry_path)
    print(f"* Loaded {len(blacklisted)} blacklisted contacts.")
    print(f"* Loaded {len(registry)} persistent registry entries (deduplication database).")

    # Load existing scraped leads if present
    existing_leads_by_id = {}
    existing_phones = set()
    existing_place_ids = set()
    existing_names = set()

    if os.path.exists(output_path):
        try:
            with open(output_path, "r", encoding="utf-8") as f:
                data = json.load(f)
                if isinstance(data, list):
                    for item in data:
                        lid = item.get("id") or item.get("hash_key")
                        if lid:
                            existing_leads_by_id[lid] = item
                        p = normalize_saudi_mobile(item.get("phone") or item.get("saudi_mobile"))
                        if p:
                            existing_phones.add(p)
                            existing_phones.add(re.sub(r"\D", "", p))
                        pid = item.get("place_id")
                        if pid:
                            existing_place_ids.add(pid)
                        cname = normalize_company_name(item.get("company_name") or "")
                        if cname:
                            existing_names.add(cname)
        except Exception as e:
            print(f"Warning: Failed to parse existing leads file: {e}")

    for item in registry.values():
        p = normalize_saudi_mobile(item.get("phone"))
        if p:
            existing_phones.add(p)
            existing_phones.add(re.sub(r"\D", "", p))
        pid = item.get("place_id")
        if pid:
            existing_place_ids.add(pid)
        cname = normalize_company_name(item.get("company_name") or "")
        if cname:
            existing_names.add(cname)

    session = requests.Session()

    total_extracted_places = 0
    discarded_non_mobile = 0
    discarded_blacklisted = 0
    discarded_duplicates = 0
    new_genuine_leads = []

    for q_entry in queries:
        query_text = q_entry["query"]
        hub_name = q_entry["hub"]
        cluster_grp = q_entry.get("cluster_group", "Core Corporate Hubs")
        intent_score = q_entry.get("intent_base", 90)

        print(f"\n--> Querying Google Maps: '{query_text}'...")
        places = query_google_maps_live(query_text, session)
        print(f"    Discovered {len(places)} real Google Place records.")
        total_extracted_places += len(places)

        for place in places:
            company_name = place["company_name"]
            place_id = place["place_id"]
            raw_phone = place["raw_phone"]
            address = place["address"]
            gmaps_url = place["google_maps_url"]
            lat = place["lat"]
            lng = place["lng"]

            # 1. Saudi Mobile Filter
            normalized_phone = normalize_saudi_mobile(raw_phone)
            if not normalized_phone:
                discarded_non_mobile += 1
                continue

            clean_digits = re.sub(r"\D", "", normalized_phone)
            norm_name = normalize_company_name(company_name)

            # 2. Deduplication Key: composite SHA-256 hash
            hash_key = generate_dedup_hash(normalized_phone, place_id)

            # 3. Pre-Ingestion Check: Multi-Field Deduplication & Blacklist Check
            if (
                normalized_phone in existing_phones
                or clean_digits in existing_phones
                or place_id in existing_place_ids
                or (norm_name and norm_name in existing_names)
                or hash_key in registry
                or hash_key in existing_leads_by_id
            ):
                discarded_duplicates += 1
                continue

            if normalized_phone in blacklisted or clean_digits in blacklisted:
                discarded_blacklisted += 1
                continue

            existing_phones.add(normalized_phone)
            existing_phones.add(clean_digits)
            existing_place_ids.add(place_id)
            if norm_name:
                existing_names.add(norm_name)

            # 4. Construct Authentic Lead Object
            # Staffing requirements tailored for Riyadh corporate offices
            staffing = ["Tea Boy", "Pantry Staff", "Cleaners"]
            contact_person = "Office / Procurement Director"

            lead_record = {
                "id": hash_key,
                "hash_key": hash_key,
                "place_id": place_id,
                "company_name": company_name,
                "contact_person": contact_person,
                "phone": normalized_phone,
                "saudi_mobile": normalized_phone,
                "address": address,
                "google_maps_url": gmaps_url,
                "zone_cluster": hub_name,
                "hub": hub_name,
                "cluster_group": cluster_grp,
                "lat": lat,
                "lng": lng,
                "staffing_requirements": staffing,
                "intent_score": intent_score,
                "date_added": today_str,
                "status": "new",
                "notes": f"Verified Google Maps profile in {hub_name}. Address: {address or 'Riyadh'}. Place ID: {place_id}.",
            }

            # 5. Post-Ingestion: Update registry and storage
            registry[hash_key] = {
                "hash_key": hash_key,
                "place_id": place_id,
                "phone": normalized_phone,
                "company_name": company_name,
                "google_maps_url": gmaps_url,
                "date_added": today_str,
            }

            existing_leads_by_id[hash_key] = lead_record
            new_genuine_leads.append(lead_record)

    # Save updated persistent registry
    save_lead_registry(registry_path, registry)

    # Save output leads
    os.makedirs(os.path.dirname(output_path) or ".", exist_ok=True)
    final_leads_list = list(existing_leads_by_id.values())
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(final_leads_list, f, indent=2, ensure_ascii=False)

    print("\n========================================")
    print("Authentic Google Maps Pipeline Complete:")
    print(f"* Total Real Places Scraped:  {total_extracted_places}")
    print(f"* Discarded Non-Mobile Lines: {discarded_non_mobile} (landlines 011, unified 9200, 800, missing)")
    print(f"* Discarded Blacklisted:      {discarded_blacklisted}")
    print(f"* Discarded Duplicates (Hash):{discarded_duplicates}")
    print(f"* New Genuine Leads Ingested: {len(new_genuine_leads)}")
    print(f"* Total Persistent Pipeline:  {len(final_leads_list)}")
    print(f"* Persistent Registry:        {registry_path} ({len(registry)} hashes)")
    print(f"* Output File:                {output_path}")
    if new_genuine_leads:
        print("* Ingested Genuine Leads:")
        for l in new_genuine_leads:
            print(f"   - {l['company_name']} ({l['saudi_mobile']}) -> {l['google_maps_url']}")
    else:
        print("* Notice: 0 new genuine mobile leads met criteria today. Strict 'Zero Data over Fake Data' enforced.")
    print("========================================")

    return new_genuine_leads

if __name__ == "__main__":
    out_file = sys.argv[1] if len(sys.argv) > 1 else "data/scraped_leads.json"
    reg_file = sys.argv[2] if len(sys.argv) > 2 else "data/lead_registry.json"
    run_pipeline(output_path=out_file, registry_path=reg_file)
