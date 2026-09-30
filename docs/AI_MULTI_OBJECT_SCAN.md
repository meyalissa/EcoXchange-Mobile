# AI Scan: Single-Object Classification and Multi-Object Detection

**Status (2026-10-01):**

- Single-object classification (`/classify`) is **live and unchanged**.
- Multi-object detection (`/detect`) is **integrated end to end** (Flutter → Laravel → FastAPI)
  and is presented in the app as **Beta** ("Count Multiple Bottles (Beta)"). Laravel marks its
  response `experimental: true`.
- Both flows start from the same photo on the same Scan & Classify screen. The customer chooses
  which one to run.
- Every AI quantity is a **suggestion**. The customer confirms or corrects it, and Laravel alone
  calculates weight, reward and centre eligibility.

---

## 1. Single-object AI flow (live, unchanged)

```
Scan & Classify screen (image_picker: camera / gallery)
  → POST /api/v1/customer/pickup/image      multipart "photo"   → { scan_log_id, image_url }
  → "Classify with AI"
  → POST /api/v1/customer/pickup/classify   { scan_log_id }
        Laravel → FastAPI /predict → EfficientNet-B0 (8 classes)
        Laravel records predicted_label/confidence on the ScanLog and matches items.ai_label
  → result: AI SUGGESTION card (item + confidence)
  → "Yes, that's right" | "No, choose manually" (real catalogue)
  → "Continue to Pickup Booking" → booking Items step with the item at quantity 1
  → estimate / centres / review / submit (unchanged; Laravel computes weight and reward)
```

The classify response `data` (unchanged; it has no `mode` field):

```json
{ "scan_log_id": 84, "ai_label": "plastic_bottle", "confidence": 0.8948,
  "item": { /* ItemResource */ }, "top_predictions": [ { "ai_label": "...", "confidence": 0.0 } ] }
```

An unsupported label is a 422 with `errors.code = "AI_LABEL_UNSUPPORTED"`, shown honestly and
followed by manual choice. This is unchanged. Multi-object detection never calls `/classify` and
never writes the ScanLog's single-object columns (`predicted_label`, `confidence_score`,
`item_id`).

## 2. Multi-object flow (live, Beta)

```
Scan & Classify screen → photo (same picker)
  → POST /api/v1/customer/pickup/image                    → { scan_log_id, image_url }
       (the app remembers scan_log_id + image_url locally — see §6)
  → "Count Multiple Bottles (Beta)"
  → POST /api/v1/customer/pickup/detect  { scan_log_id }
       Laravel AIInferenceService::detect()
         → FastAPI POST /detect
              → RetinaNet 640 generic "bottle" detector
              → crop each detected object
              → EfficientNet-B0 material classifier, per crop
         → Laravel validates the response
         → Laravel resolves each material label to an item (items.ai_label, active items)
         → Laravel saves the result on the same ScanLog (scan_logs.detection_result)
  → Flutter multi-object review: every object + material, quantity per material (editable)
  → "Continue with N items" → existing booking flow, pre-filled with the CONFIRMED quantities
  → estimate / centres / review / submit — Laravel computes weight, reward and eligibility
```

The app waits up to 40 s for `/detect` (`ApiConfig.detectReceiveTimeout`), because Laravel
allows the AI service up to 30 s. Every other request keeps the existing 15 s.

**Key files**

| Area | File |
|---|---|
| Screen (picker, preview with both buttons, loading, results, manual picker) | `lib/features/customer/presentation/screens/scan/scan_classify_screen.dart` |
| Multi-object review UI | `lib/features/customer/presentation/screens/scan/multi_object_result_view.dart` |
| State (both flows, corrections, manual items, resume) | `lib/features/customer/presentation/providers/ai_scan_provider.dart` |
| API calls (`uploadImage`, `classify`, `detect`, `storedDetection`, estimate, centres, review, submit) | `lib/features/customer/data/repositories/customer_pickup_booking_repository.dart` |
| Analysis abstraction (`ClassifierScanRepository`, `DetectionScanRepository`) | `lib/features/customer/data/repositories/ai_scan_repository.dart` |
| Local memory of the last unfinished multi-object scan | `lib/features/customer/data/pending_detection_store.dart` |
| Result model | `lib/features/customer/data/models/ai_scan_result.dart` |
| HTTP client, envelope, error mapping | `lib/core/api/api_client.dart`, `lib/core/api/api_exception.dart`, `lib/core/api/api_config.dart` |
| Booking flow | `lib/features/customer/presentation/screens/booking/*`, `providers/pickup_booking_provider.dart` |

## 3. Detector vs classifier semantics

| | Detector (RetinaNet 640) | Classifier (EfficientNet-B0) |
|---|---|---|
| Answers | *Where are the bottles?* | *What material is this object?* |
| Field | `detector_label` — always the generic **`bottle`** | `classification_label` — e.g. `glass_bottle`, `plastic_bottle`, `aluminium_can`, or none |
| Used for items / quantities | **Never** | **Yes** — the only source of material |

- `bottle` is **not** `plastic_bottle`. The detector's class covers plastic and glass bottles
  alike. Neither Laravel nor the app ever maps `bottle` to an item.
- The app shows both separately, e.g. `Object 3 · detected as "bottle" (85%)` and, below it, the
  classifier's material (`Plastic Bottle`, `Material confidence: 62%`).
- An object the classifier could not classify gets **no material and no item**.
- Automatic counts are not guaranteed. The classifier was trained on whole-item photos and has
  not been independently validated on detector crops, so the customer's confirmation remains the
  authority.

## 4. Result model and multi-object review

`lib/features/customer/data/models/ai_scan_result.dart` parses both responses. A body without
`mode` is the classify response (single-object); `mode: "multi_object"` is the `/detect`
response (and its read-back, which has the same shape).

| Type | Purpose |
|---|---|
| `AIScanResult` | `mode`, `scanLogId`, `classification` (single only), `detections`, `materials` (all counted materials), `lines` (materials resolved to an item — the only bookable ones), `unresolvedMaterials`, `imageWidth`/`imageHeight`, `needsManualReview`. |
| `AIDetectedObject` | `id` (e.g. `object_1`), display `index`, `detectorLabel`, `detectorConfidence`, `boundingBox`, `classificationStatus` (classified/unclassified), `aiLabel`, `classificationConfidence`, `unclassifiedReason`, `itemStatus`, `item`. |
| `AIItemStatus` | `resolved` (active item found — counted), `unresolved` (label has no active item — not counted), `notClassified` (no material — not counted). |
| `AIScanLine` | `aiLabel`, `item` (null when unresolved), `suggestedQuantity`. |
| `AIBoundingBox` | x, y, width, height in **original-image pixels**, origin top-left, as the server sends them. The view scales them by the reported image size to draw the boxes. |

An unknown `classification_status` or `item_status`, a missing field, or a non-multi-object body
from `/detect` is rejected as malformed (§9) — never partially trusted.

**What the review screen shows** (`MultiObjectResultView`):

- The photo with a numbered box per object (green when counted, amber when it needs review).
- "AI DETECTED OBJECTS": per object, the detector label and confidence, the material and its
  confidence, and a review reason when not counted ("Material unclear · needs manual review",
  "Not available on EcoXchange · needs manual review", …).
- A "needs manual review" notice when any object is unresolved or unclassified, and
  "N counted · M need manual review".
- "Confirm quantities": one line per resolved material with "AI suggested quantity: N" and a
  stepper; unresolved materials are listed as "not available on EcoXchange, not counted".
- "Final weight and reward are calculated by EcoXchange from the quantities you confirm."
- Buttons: "Continue with N items", "Add an Item Manually", "Scan Another Photo".
- With zero detections: "No Items Detected", with "Choose Item Manually" (the existing
  single-item path) and "Scan Another Photo".

## 5. Quantities, correction and manual items

- **Grouping.** The suggested quantity per material is Laravel's `summary.materials` count of
  classified objects with that label. Only **resolved** materials become quantity lines.
- **Suggestions only.** Lines read "AI suggested quantity: N".
- **Correction.** Each line has the existing `QuantityStepper` (+ / −, minimum 0). A correction
  is stored in `AIScanProvider` separately from the AI suggestion, which is never overwritten.
  An edited line shows "Edited by you" and **"Use AI suggestion"** to reset. Setting the value
  back to the AI number also clears the edited state.
- **Manual review.** Unresolved and unclassified objects are never counted automatically. The
  customer can resolve them with "Add an Item Manually", which opens the real catalogue. A
  picked item is added at quantity 1 and labelled **"Added by you (not detected by AI)"**; picking
  an item the AI already suggested increments that line instead.
- **Lifetime.** Corrections and manual items last until reset, a new photo, or a new scan.
- A line at 0 is not booked; "Continue" is disabled when nothing is left to book.

## 6. Persistence and resume

### Server side (Laravel)

`POST /detect` stores the result in **`scan_logs.detection_result`** (nullable JSON) on the
**same ScanLog** as the uploaded photo — never one row per object.

- It is saved only after FastAPI answered, Laravel validated the response, and the materials
  were resolved to items.
- A **failed** detection (AI unavailable, rejected image, malformed response) writes nothing;
  an existing saved result is kept.
- A **repeated successful** detection of the same ScanLog replaces the previous saved result.

Saved structure (`schema_version` 1):

```json
{
  "schema_version": 1,
  "detected_at": "…",
  "image": { "width": 640, "height": 640 },
  "detector_model_version": "retinanet_efficientnetb0_640_lr_decay_best_e27",
  "detector_confidence_threshold": 0.5,
  "classifier_model_version": "ecoxchange_efficientnet_b0_8class",
  "detections": [
    { "id": "object_1", "detector_label": "bottle", "detector_confidence": 0.9623,
      "bounding_box": { "x": 160.8, "y": 243.04, "width": 161.41, "height": 259.5 },
      "classification_status": "classified", "classification_label": "glass_bottle",
      "classification_confidence": 0.8731, "unclassified_reason": null, "top_predictions": [ … ],
      "item_status": "resolved", "item_id": 10 }
  ],
  "summary": {
    "total_detected_objects": 4, "classified_objects": 4, "unclassified_objects": 0,
    "resolved_objects": 4, "unresolved_objects": 0, "needs_manual_review": false,
    "materials": [ { "ai_label": "glass_bottle", "suggested_quantity": 3, "item_id": 10, "item_status": "resolved" } ]
  },
  "timing": { … }
}
```

It holds item **ids** only — no weight, price, reward, eligibility or pickup-item data.

`GET /api/v1/customer/pickup/detect/{scanLog}` returns the saved result in the same shape as
`POST /detect`:

- It **does not call FastAPI** and runs no new inference.
- It uses the **stored item ids**, so the item mapping from detection time is kept even if the
  catalogue changes later.
- The ScanLog must belong to the customer and not yet be attached to a pickup.

### App side (Flutter)

- Right **after the upload** (before `/detect` runs), `AIScanProvider.submitMultiObject()`
  stores the `scan_log_id` and `image_url` locally (`SecurePendingDetectionStore`, using the
  app's existing flutter_secure_storage). Only these two values are stored, never the AI result.
- When the Scan & Classify screen is created — after reopening it or restarting the app —
  `resumePendingDetection()` calls `GET /detect/{scanLog}` and shows the saved result with the
  notice "Showing your last scan, saved on EcoXchange. The AI was not run again." The photo is
  shown from the server's `image_url`.
- A successful POST is **not** followed by a GET; the GET is only for recovery.
- Restoring brings back the **saved AI suggestion**, not unsaved user edits (§11).
- The remembered scan is forgotten on "Scan Another Photo", when a new photo is picked, or when
  the read-back returns 404 (e.g. the scan was used by a pickup).

## 7. Booking hand-off

- "Continue with N items" passes `AIScanProvider.reviewedQuantities` — the **user-confirmed**
  quantities (AI suggestion unless corrected, plus manual items, lines above 0) — to the
  existing `PickupBookingScreen(prefillQuantities: …, prefillScanLogId: …, prefillImageUrl: …)`
  and `PickupBookingProvider`. There is no second booking implementation.
- The Items step shows the notice that the quantities were suggested by AI, and they stay
  editable there.
- The same `scan_log_id` becomes the booking's photo (no second upload).
- The existing `/pickup/estimate`, `/centres`, `/review` and `/pickup` endpoints remain the
  authority. The app sends only `item_id` + `quantity`.

## 8. Laravel is the authority for weight, reward and eligibility

Flutter never calculates weight, reward or centre eligibility, and none is derived from the AI
response. Laravel computes weight from `quantity × item.estimated_unit_weight_kg`, applies the
centre-specific rate, checks centre eligibility, and returns the numbers the app displays
verbatim. After submission, `pickup_items` holds the customer's confirmed quantities;
`detection_result` stays the original AI suggestion.

## 9. Error handling

No error path ever produces a fake or fallback AI result. A failed scan leaves no result on screen,
and the preview offers the manual paths again.

| Case | App behaviour |
|---|---|
| **401** | Existing session handling: `ApiClient` fires `onUnauthorized`, and the auth flow clears the session. |
| **403** (not a customer) | The server's message is shown; no result. |
| **404** on read-back (`IMAGE_INVALID`, `DETECTION_NOT_FOUND`) | Nothing is restored and no error is shown; the remembered scan is forgotten and the normal empty Scan screen appears. |
| **422** (validation, `IMAGE_INVALID`, `AI_INVALID_IMAGE`, `IMAGE_UNREADABLE`) | The server's message is shown; no result. |
| **503** (`AI_SERVICE_UNAVAILABLE`, `AI_DETECTOR_UNAVAILABLE`, `AI_SERVICE_ERROR`, `AI_INVALID_RESPONSE`) | "AI classification is temporarily unavailable. Please try again or use manual selection." |
| **Timeout** (40 s for `/detect`) / no connection | The existing timeout / network message. Because the scan was remembered before detection, a result Laravel saved anyway can still be restored later. |
| **Malformed response** (fails the app's parser) | "The AI scan result could not be read. Please try again or use manual selection." (code `AI_INVALID_RESPONSE`). |
| Network failure during read-back | Nothing restored; the remembered scan is kept for a later attempt. |

`ServerException` now carries the HTTP `statusCode` and Laravel's `errors.code`, so 404 and 503
are told apart by code rather than by message text.

## 10. Real verification (2026-09-30)

Full stack on the local environment: Android emulator (Medium Phone API 36.1) → Laravel
(Laragon, MySQL) → FastAPI `/detect` → RetinaNet 640 → EfficientNet-B0. Detector test image
`-37_jpg.rf.cfec2e9459be7328087ec91601c395eb.jpg`, demo customer account.

| Check | Result |
|---|---|
| Objects detected | **4 bottles**, every detector label `bottle` |
| AI-suggested quantities | **Glass Bottle × 3, Plastic Bottle × 1** |
| Correction in the app | Changed to **Glass × 2 + Plastic × 2**; "Use AI suggestion" restored 3 |
| Booking | The Items step showed the corrected quantities. The Centre step's rewards (RM 1.05 / 0.09 / 0.12 / 0.08) matched Laravel's calculation for 2 + 2 — not for the AI's 3 + 1 (RM 1.52 / 0.09 / 0.13 / 0.06) |
| Persistence | `detection_result` saved on the ScanLog (glass 3 → item 10, plastic 1 → item 1); single-object columns and `pickup_id` stayed NULL |
| Screen reopened | Restored through `GET /detect/{scanLog}` |
| Full app restart | Restored through `GET /detect/{scanLog}` |
| Inference during restore | None — no additional FastAPI `/detect` call |
| FastAPI stopped | Laravel returned 503; the app showed the "temporarily unavailable" message and no result |
| Pickup submission | **None** was submitted during the verification |

The test ScanLogs, their images and the temporary API token were removed afterwards.

## 11. Known limitations

1. **Photo re-encoding.** The existing image picker re-encodes photos as JPEG at quality 80,
   which can slightly change AI confidences compared with the original file (in the verification,
   one plastic bottle scored 62% via the app versus 83% from the original file; the counts were
   the same).
2. **Restore returns the AI suggestion.** A restored result contains the saved AI suggestions,
   not the customer's unsaved edits.
3. **Item fields in the detection response.** `/detect` currently exposes only item
   `id` / `name` / `category` (and `ai_label`), not item pricing, so the booking Items step shows
   no catalogue price for items pre-filled from a scan. Weight and reward are still computed by
   Laravel.
4. **Emulator storage.** The test emulator had about 620 MB free; the universal debug APK could
   not be updated in place, so an x86_64-only debug build was installed for the verification.
5. **Saved-scan lifecycle.** The remembered scan is cleared by the existing lifecycle ("Scan
   Another Photo", a new photo, or a 404 read-back once the scan is used by a pickup), not
   immediately on submission.
6. **Beta / experimental.** Multi-object detection is presented as **Beta** in the app ("Count
   Multiple Bottles (Beta)") and marked `experimental: true` by Laravel. Automatic counts are
   suggestions, not guarantees.

## 12. Tests

Unit/widget inputs are **test fixtures** (`test/fixtures/ai_scan_fixtures.dart`): hand-written
bodies in the real `/detect` contract, plus one **genuine** Laravel `/detect` response recorded
from the real stack (`test/fixtures/detect_response_real_laravel_4_bottles.json`). The HTTP
boundary is faked; no detector runs in Flutter tests.

| File | Covers |
|---|---|
| `test/features/customer/ai_scan_result_test.dart` | Single-object parsing (backward compatible); the genuine Laravel response; one / two plastic bottles; mixed glass × 3 + plastic × 2; unclassified object gets no material; unresolved material; empty result; unknown mode/status rejected |
| `test/features/customer/ai_scan_multi_object_test.dart` | `/detect` request (path, body, timeout) and read-back path; malformed responses rejected; `/classify` path unchanged; detect flow; quantity correction and reset; manual items; 503 message; timeout/401/403/422 errors; read-back restore without inference; 404 read-back; network failure keeps the remembered scan; no GET after a successful POST; corrected quantities reach `PickupBookingProvider` and its estimate request |
| `test/features/customer/multi_object_result_view_test.dart` | Review UI (detector vs material info, quantities); one/two/mixed; unclassified shown for manual review; correction and "Use AI suggestion"; continue disabled at 0; manual item label; empty and nothing-countable states; bounding boxes; restored-result notice |
| `test/features/customer/ai_scan_provider_test.dart` (unchanged) | Single-object classify, unsupported, errors, confirm and reset |

Current results (2026-09-30):

- `flutter test`: **119 passed, 0 failed**
- `flutter analyze`: **no new issues**; 4 existing `info` lints (`use_null_aware_elements`)
- `flutter build apk --debug`: **successful**
