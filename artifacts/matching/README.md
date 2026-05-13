# Customer Matching Logic

Place all customer matching and deduplication scripts here. Scripts are automatically uploaded to S3 during `terraform apply`.

## Purpose

Matching scripts implement the core customer deduplication logic:
- **Blocking rules** — reduce comparison volume by grouping similar records
- **Fuzzy matching** — compare names, addresses, emails using similarity algorithms
- **Scoring logic** — weighted scoring based on TIN, email, birthdate, name similarity
- **Classification** — categorize record pairs into Merge, Manual Review, or Unique

## Expected Scripts

1. **blocking_rules.py** — Defines blocking keys (same birthdate + similar name, same mobile, etc.)
2. **fuzzy_name_matcher.py** — Name similarity using rapidfuzz
3. **scoring_engine.py** — Weighted scoring logic (TIN: high, email: high, name: medium)
4. **classifier.py** — Threshold-based classification (score 90-100: Merge, 70-89: Manual Review, 0-69: Unique)

## Dependencies

Matching scripts typically use:
- `pandas` — data manipulation
- `rapidfuzz` — fuzzy string matching
- `recordlinkage` — blocking and candidate pair generation

## S3 Upload Path

Scripts are uploaded to: `s3://cdcu-{env}-data-lake/{env}/matching-scripts/`

## Integration with SageMaker

Matching scripts are imported by SageMaker processing jobs. Example:

```python
# In sagemaker/matching_processor.py
from matching.blocking_rules import generate_candidate_pairs
from matching.fuzzy_name_matcher import compute_name_similarity
from matching.scoring_engine import calculate_match_score
from matching.classifier import classify_match

# Use the imported functions
candidates = generate_candidate_pairs(df_microsite, df_legacy)
candidates['name_score'] = candidates.apply(compute_name_similarity, axis=1)
candidates['match_score'] = candidates.apply(calculate_match_score, axis=1)
candidates['match_status'] = candidates['match_score'].apply(classify_match)
```
