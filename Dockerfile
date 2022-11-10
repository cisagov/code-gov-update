FROM python:3.10.8-alpine3.16 as compile-stage

###
# For a list of pre-defined annotation keys and value types see:
# https://github.com/opencontainers/image-spec/blob/master/annotations.md
#
# Note: Additional labels are added by the build workflow.
###
LABEL org.opencontainers.image.authors="vm-fusion-dev-group@trio.dhs.gov"
LABEL org.opencontainers.image.vendor="Cybersecurity and Infrastructure Security Agency"

# Unprivileged user information necessary for the Python virtual environment
ARG CISA_USER="cisa"
ENV CISA_HOME="/home/${CISA_USER}"
ENV VIRTUAL_ENV="${CISA_HOME}/.venv"

# Configure cargo to use the git CLI instead of the libgit2 library. There is
# an issue with 32-bit (non-x86) platforms when ligbit2 tries to pull down the
# cargo package index from GitHub. This *might* be fixed in a more recent version
# of cargo so it is being tracked in:
# https://github.com/cisagov/code-gov-update/issues/32
RUN mkdir --parents ~/.cargo && printf "[net]\ngit-fetch-with-cli = true\n" >> ~/.cargo/config.toml

# Install the dependencies necessary to build the cryptography Python
# package. These are required to build the package if a pre-built wheel
# is not available on PyPI.
RUN apk --no-cache add \
  cargo=1.60.0-r2 \
  gcc=11.2.1_git20220219-r2 \
  git=2.36.3-r0 \
  libffi-dev=3.4.2-r1 \
  musl-dev=1.2.3-r2 \
  openssl-dev=1.1.1s-r0 \
  python3-dev=3.10.8-r0

# Install pipenv to manage installing the Python dependencies into a created
# Python virtual environment. This is done separately from the virtual
# environment so that pipenv and its dependencies are not installed in the
# Python virtual environment used in the final image.
RUN python3 -m pip install --no-cache-dir --upgrade pipenv==2022.10.12 \
  # Manually create Python virtual environment for the final image
  && python3 -m venv ${VIRTUAL_ENV} \
  # Ensure the core Python packages are installed in the virtual environment
  && ${VIRTUAL_ENV}/bin/python3 -m pip install --no-cache-dir --upgrade \
    pip==22.3 \
    setuptools==65.5.0 \
    wheel==0.37.1

# Install code-gov-update Python requirements
WORKDIR /tmp
COPY src/Pipfile src/Pipfile.lock ./
RUN pipenv sync --clear --verbose

FROM python:3.10.8-alpine3.16 as build-stage

###
# Unprivileged user setup variables
###
ARG CISA_UID=421
ARG CISA_GID=${CISA_UID}
ARG CISA_USER="cisa"
ENV CISA_GROUP=${CISA_USER}
ENV CISA_HOME="/home/${CISA_USER}"
ENV VIRTUAL_ENV="${CISA_HOME}/.venv"

# Create unprivileged user
RUN addgroup --system --gid ${CISA_GID} ${CISA_GROUP} \
  && adduser --system --uid ${CISA_UID} --ingroup ${CISA_GROUP} ${CISA_USER}

# Install the dependencies needed by the llnl-scraper Python package to
# estimate labor hours for code.
RUN apk --no-cache add \
  cloc=1.92-r0 \
  git=2.36.3-r0

# Copy in the Python venv we created in the compile stage
COPY --from=compile-stage --chown=${CISA_USER}:${CISA_GROUP} ${VIRTUAL_ENV} ${VIRTUAL_ENV}
ENV PATH="${VIRTUAL_ENV}/bin:$PATH"

# Copy in the necessary files
COPY --chown=${CISA_USER}:${CISA_GROUP} src/update.sh src/email-update.py src/body.txt src/body.html ${CISA_HOME}/

# Prepare to Run
WORKDIR ${CISA_HOME}
USER ${CISA_USER}
ENTRYPOINT ["./update.sh"]
