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

# Versions of the Python packages installed directly
ENV PYTHON_PIP_VERSION=23.0.1
ENV PYTHON_PIPENV_VERSION=2023.2.18
ENV PYTHON_SETUPTOOLS_VERSION=67.6.0
ENV PYTHON_WHEEL_VERSION=0.40.0

# Install the dependencies necessary to build the cryptography Python
# package. These are required to build the package if a pre-built wheel
# is not available on PyPI.
RUN apk --no-cache add \
  cargo=1.64.0-r2 \
  gcc=12.2.1_git20220924-r4 \
  git=2.38.5-r0 \
  libffi-dev=3.4.4-r0 \
  musl-dev=1.2.3-r5 \
  openssl-dev=3.0.9-r3 \
  py3-pip=22.3.1-r1 \
  py3-setuptools=65.6.0-r0 \
  py3-wheel=0.38.4-r0 \
  python3-dev=3.10.13-r0 \
  python3=3.10.13-r0

# Copy in our custom Cargo configuration file
COPY src/config.toml /root/.cargo/

# Install pipenv to manage installing the Python dependencies into a created
# Python virtual environment. This is done separately from the virtual
# environment so that pipenv and its dependencies are not installed in the
# Python virtual environment used in the final image.
RUN python3 -m pip install --no-cache-dir --upgrade pipenv==${PYTHON_PIPENV_VERSION} \
  # Manually create Python virtual environment for the final image
  && python3 -m venv ${VIRTUAL_ENV} \
  # Ensure the core Python packages are installed in the virtual environment
  && ${VIRTUAL_ENV}/bin/python3 -m pip install --no-cache-dir --upgrade \
    pip==${PYTHON_PIP_VERSION} \
    setuptools==${PYTHON_SETUPTOOLS_VERSION} \
    wheel==${PYTHON_WHEEL_VERSION}

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

# Install the dependencies needed by the llnl-scraper Python package to
# estimate labor hours for code.
RUN apk --no-cache add \
  cloc=1.94-r0 \
  git=2.38.5-r0

# Create unprivileged user
RUN addgroup --system --gid ${CISA_GID} ${CISA_GROUP} \
  && adduser --system --uid ${CISA_UID} --ingroup ${CISA_GROUP} ${CISA_USER}

# Copy in the Python venv we created in the compile stage and re-symlink
# python3 in the venv to the Python binary in this image
COPY --from=compile-stage --chown=${CISA_USER}:${CISA_GROUP} ${VIRTUAL_ENV} ${VIRTUAL_ENV}
RUN ln -sf "$(command -v python3)" "${VIRTUAL_ENV}"/bin/python3
ENV PATH="${VIRTUAL_ENV}/bin:$PATH"


# Copy in the necessary files
COPY --chown=${CISA_USER}:${CISA_GROUP} src/update.sh src/email-update.py src/body.txt src/body.html ${CISA_HOME}/

# Prepare to run
WORKDIR ${CISA_HOME}
USER ${CISA_USER}:${CISA_GROUP}
ENTRYPOINT ["./update.sh"]
