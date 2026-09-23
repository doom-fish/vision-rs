# Vision.framework Coverage Audit (v2) — withdrawn

This v2 re-audit has been withdrawn. Its exemption table and parts of its
verified tables listed symbols that do not exist in the Vision SDK (for
example `VNBodyLandmarkKey_mouth`, `VNDataStructureCodec`,
`VNImageRequestHandler_revisionDefault`, `VNInstantDoubleHEICTransformer`
and `VNDetectFaceProtectiveEquipmentRequest`), its 238-symbol
re-enumeration could not be reproduced, and its summary figures were not
internally consistent.

The current figures are in [`COVERAGE_AUDIT.md`](COVERAGE_AUDIT.md): 249
symbols, 222 verified, 27 exempt, 89.16%. The 27 exemptions are the 25
deprecated `VNBodyLandmarkKey*` constants and the 2 deprecated
`VNVideoProcessingOption*` keys, none of which appear in the macOS 26.5
headers.
