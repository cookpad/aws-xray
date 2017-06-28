# CHANGELOG
Only breaking or notable changes.

## v0.31.0
- Rename tracing methods while keeping old methods:
  - `#base_trace` -> `#start_segment`
  - `#child_trace` -> `#start_subsegment`

## v0.30.0
- Drop faraday dependency. Users who want to use Faraday middleware must require `aws/xray/faraday`.
