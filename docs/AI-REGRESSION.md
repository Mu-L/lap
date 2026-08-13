AI Image Search Regression Test (instructions)

Purpose

Reproduce and prevent regressions where text and image embeddings use mismatched spaces, causing poor similarity results.

How to run (developer machine)

1. Ensure model files are present in resources/models (for dev builds this resolves to <repo-root>/src-tauri/resources/models):
   - vision_model.onnx
   - text_model.onnx
   - tokenizer.json

2. Set environment variable to enable integration test run:
   - export LAP_RUN_AI_TESTS=1

3. Run the integration test (from repo root):
   - cd src-tauri
   - cargo test --test ai_integration -- --nocapture

What the test should do (provided as a reference snippet)

// Pseudocode
// - Start a minimal tauri::App or mock AppHandle
// - Create AiEngine, load models via load_models(app_handle)
// - Call ai_engine.fetch_text_embedding_dim() and fetch_vision_embedding_dim()
// - Assert dims equal
// - Run a sample text query and image encoding, then call AFile::cosine_similarity_blob and assert top-k ranking contains expected file ids

Notes

- This repository's CI may not include the large ONNX model files by default. The test is gated behind LAP_RUN_AI_TESTS to avoid failing CI.
- If models do not match, the engine will attempt fallbacks between Default and Multilingual text models. If still mismatched the load will fail with a helpful message.
