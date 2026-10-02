# Food evaluation fixtures

15-20 small JPEGs (no people, no copyrighted images) plus `labels.json`, used only by the opt-in live evaluation
(`RUN_AI_EVAL=1`, see `GatorPlateTests/Evaluation/FoodEvaluationTests.swift`). Never added to the app target.

`labels.json`:

```json
[
  {
    "file": "pizza.jpg",
    "expectFood": true,
    "expectPeople": false,
    "itemKeywords": ["pizza"],
    "dietary": "vegetarian"
  },
  { "file": "laptop.jpg", "expectFood": false, "expectPeople": false },
  { "file": "friend-holding-bagel.jpg", "expectFood": true, "expectPeople": true }
]
```

`dietary` is the true overall class (`vegan`, `vegetarian`, `non_vegetarian`, `mixed`) or omitted when unknowable.
A **false vegan** is any photo whose true class is not `vegan` that the app labels `vegan`.
