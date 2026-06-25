# syntax=docker/dockerfile:1.7
#
# Commit-image Dockerfile for pip (Atheris / Python harness) — builds ON TOP of the org base
# image (ghcr.io/mayhemheroes/base): debian + clang/llvm + libFuzzer + python3 + the build-contract
# ENV + the mayhem identity. This adds the per-commit fuzz build.

FROM ghcr.io/mayhemheroes/base:20260621

ARG COMMIT
ARG REPO_URL
# SOURCE_DATE_EPOCH stays an ARG (available to build.sh); never bake it as ENV — an empty value
# breaks clang. build.sh unsets it when empty.
ARG SOURCE_DATE_EPOCH
# Sanitizer override (undefaulted so the base ENV flows through when not passed).
ARG SANITIZER_FLAGS
ARG COVERAGE_FLAGS=
ARG MAYHEM_JOBS=

# Install Atheris (the Python fuzzing engine) as root, system-wide, from a wheelhouse baked into
# the image: build the wheel online ONCE, then install it offline from the cache. This keeps the
# air-gapped build.sh re-run (SPEC §6.5) from ever reaching PyPI.
USER root
RUN python3 -m pip wheel --wheel-dir=/opt/wheelhouse atheris \
 && python3 -m pip install --no-index --find-links=/opt/wheelhouse --break-system-packages atheris \
 && chown -R 2000:2000 /opt/wheelhouse

# Source enters from the build CONTEXT (the CI checkout): the FULL repo (incl. .git history) is
# copied to /mayhem; build.sh builds in place.
USER mayhem
WORKDIR /mayhem
COPY --chown=2000:2000 . /mayhem

RUN bash mayhem/build.sh

# Run the functional tests at build time — a failing suite fails the image build.
RUN if [ -f mayhem/test.sh ]; then bash mayhem/test.sh; else echo "no mayhem/test.sh"; fi

LABEL org.opencontainers.image.source="${REPO_URL}" \
      org.opencontainers.image.revision="${COMMIT}" \
      rlenv.tier="commit" \
      rlenv.source_date_epoch="${SOURCE_DATE_EPOCH}" \
      rlenv.user="mayhem"

USER mayhem
WORKDIR /mayhem
