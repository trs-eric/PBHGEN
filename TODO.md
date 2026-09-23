# PBHGEN TODO

## Reliability and development speed

- [ ] Add a deterministic synchronous CLI mode whose exit means the header is complete.
- [ ] Add golden-file regression tests from real PureBasic projects and return nonzero with precise diagnostics when a declaration cannot be represented.
- [ ] Correct tab-indented procedure boundaries, multiline procedure signatures, and signatures with more than six parameters.
- [ ] Write headers atomically and preserve the existing file when generated content is identical.
- [ ] Add one batch invocation for multiple changed source files.
- [ ] Add `--check`, `--output`, `--version`, and machine-readable diagnostics.
- [ ] Establish reproducible builds and a tested PureBasic/Windows compatibility matrix.
