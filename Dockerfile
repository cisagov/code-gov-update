# We use an Alpine base image in the compile-stage because of the build
# requirements for some of the Python requirements. When the python3-dev
# package is installed it will also install the python3 package which leaves us
# with two Python installations if we use a Python Docker image. Instead we use
# Alpine's python3 package here to create the virtual environment we will use
# in the Python Docker image we use for the build-stage. The tag of the Python
# Docker image matches the version of the python3 package available on Alpine
# for consistency.
FROM alpine:3.17 as compile-stage

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
  cargo=1.64.0-r2 \
  gcc=12.2.1_git20220924-r4 \
  git=2.38.4-r0 \
  libffi-dev=3.4.4-r0 \
  musl-dev=1.2.3-r4 \
  openssl-dev=3.0.8-r0 \
  py3-pip=22.3.1-r1 \
  py3-setuptools=65.6.0-r0 \
  py3-wheel=0.38.4-r0 \
  python3-dev=3.10.10-r0 \
  python3=3.10.10-r0

# Install pipenv to manage installing the Python dependencies into a created
# Python virtual environment. This is done separately from the virtual
# environment so that pipenv and its dependencies are not installed in the
# Python virtual environment used in the final image.
RUN python3 -m pip install --no-cache-dir --upgrade pipenv==2022.11.25 \
  # Manually create Python virtual environment for the final image
  && python3 -m venv ${VIRTUAL_ENV} \
  # Ensure the core Python packages are installed in the virtual environment
  && ${VIRTUAL_ENV}/bin/python3 -m pip install --no-cache-dir --upgrade \
    pip==22.3.1 \
    setuptools==65.6.3 \
    wheel==0.38.4

# Install code-gov-update Python requirements
WORKDIR /tmp
COPY src/Pipfile src/Pipfile.lock ./
RUN pipenv sync --clear --verbose

# The version of Python used here should match the version of the Alpine
# python3 package installed in the compile-stage.
FROM python:3.10.10-alpine3.17 as build-stage

# Unprivileged user information
ARG CISA_UID=2048
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
  cloc=1.94-r0 \
  git=2.38.4-r0

# Copy in the Python venv we created in the compile stage and re-symlink
# python3 in the venv to the Python binary in this image
COPY --from=compile-stage --chown=${CISA_USER}:${CISA_GROUP} ${VIRTUAL_ENV} ${VIRTUAL_ENV}
RUN ln -sf "$(command -v python3)" "${VIRTUAL_ENV}"/bin/python3
ENV PATH="${VIRTUAL_ENV}/bin:$PATH"


# Copy in the necessary files
COPY --chown=${CISA_USER}:${CISA_GROUP} src/update.sh src/email-update.py src/body.txt src/body.html ${CISA_HOME}/

# Prepare to Run
WORKDIR ${CISA_HOME}
USER ${CISA_USER}
ENTRYPOINT ["./update.sh"]
