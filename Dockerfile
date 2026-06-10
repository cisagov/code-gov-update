# We use an Alpine base image in the compile-stage because of the build
# requirements for some of the Python requirements. When the python3-dev
# package is installed it will also install the python3 package which leaves us
# with two Python installations if we use a Python Docker image. Instead we use
# Alpine's python3 package here to create the virtual environment we will use
# in the Python Docker image we use for the build-stage. The tag of the Python
# Docker image matches the version of the python3 package available on Alpine
# for consistency.
#
# Official Docker images are in the form library/<app> while non-official
# images are in the form <user>/<app>.
FROM docker.io/library/alpine:3.24 AS compile-stage

###
# Unprivileged user variables
###
ARG CISA_USER="cisa"
ENV CISA_HOME="/home/${CISA_USER}"
ENV VIRTUAL_ENV="${CISA_HOME}/.venv"

# Versions of the Python packages installed directly.  These are the
# current latest versions for Python 3.12.
ENV PYTHON_PIP_VERSION=26.0.1
ENV PYTHON_PIPENV_VERSION=2026.0.3
ENV PYTHON_SETUPTOOLS_VERSION=82.0.0

# Install the system package dependencies necessary to set up the
# image's Python virtual environment.
RUN apk --no-cache add \
  gcc=15.2.0-r2 \
  libffi-dev=3.5.2-r0 \
  musl-dev=1.2.5-r23 \
  # This package is being installed because we want to avoid building
  # wheels on some of the hardware platforms we support.  Note that we
  # must install it both here and in the build stage for this to work.
  py3-cryptography=46.0.7-r0 \
  python3-dev=3.12.13-r0 \
  python3=3.12.13-r0

###
# Create a Python virtual environment (venv) for setup (due to PEP 668), install the
# specified versions of pip and setuptools into the setup venv, install the
# specified version of pipenv into the setup venv, create the image dependency venv,
# and install the specified versions of pip and setuptools into the dependency venv.
#
# Note that we use the --no-cache-dir flag to avoid writing to a local
# cache.  This results in a smaller final image, at the cost of
# slightly longer install times.
###
RUN python3 -m venv --system-site-packages /usr/local \
    # Ensure the core Python packages are installed in the virtual environment
    && /usr/local/bin/python3 -m pip install --no-cache-dir --upgrade \
        pip==${PYTHON_PIP_VERSION} \
        setuptools==${PYTHON_SETUPTOOLS_VERSION} \
    && /usr/local/bin/python3 -m pip install --no-cache-dir --upgrade \
        pipenv==${PYTHON_PIPENV_VERSION} \
    # Manually create the virtual environment
    && python3 -m venv --system-site-packages ${VIRTUAL_ENV} \
    # Ensure the core Python packages are installed in the virtual environment
    && ${VIRTUAL_ENV}/bin/python3 -m pip install --no-cache-dir --upgrade \
        pip==${PYTHON_PIP_VERSION} \
        setuptools==${PYTHON_SETUPTOOLS_VERSION}

###
# Check the Pipfile configuration and then install the Python dependencies into
# the virtual environment.
#
# Note that pipenv will install into a virtual environment if the VIRTUAL_ENV
# environment variable is set.
###
WORKDIR /tmp
COPY src/Pipfile src/Pipfile.lock ./
RUN pipenv install --clear --deploy --extra-pip-args "--no-cache-dir" --verbose

# The version of Python used here should match the version of the Alpine
# python3 package installed in the compile-stage.
#
# Official Docker images are in the form library/<app> while non-official
# images are in the form <user>/<app>.
FROM docker.io/library/python:3.12.13-alpine3.23 AS build-stage

###
# For a list of pre-defined annotation keys and value types see:
# https://github.com/opencontainers/image-spec/blob/master/annotations.md
#
# Note: Additional labels are added by the build workflow.
###
LABEL org.opencontainers.image.authors="vm-dev@gwe.cisa.dhs.gov"
LABEL org.opencontainers.image.vendor="Cybersecurity and Infrastructure Security Agency"

###
# Unprivileged user setup variables
###
ARG CISA_UID=2048
ARG CISA_GID=${CISA_UID}
ARG CISA_USER="cisa"
ENV CISA_GROUP=${CISA_USER}
ENV CISA_HOME="/home/${CISA_USER}"
ENV VIRTUAL_ENV="${CISA_HOME}/.venv"

# Install the dependencies needed by the llnl-scraper Python package to
# estimate labor hours for code.
RUN apk --no-cache add \
  cloc=2.06-r0 \
  git=2.52.0-r0 \
  py3-cryptography=46.0.7-r0

###
# Create unprivileged user
###
RUN addgroup --system --gid ${CISA_GID} ${CISA_GROUP} \
  && adduser --system --uid ${CISA_UID} --ingroup ${CISA_GROUP} ${CISA_USER}

###
# Copy in the Python virtual environment created in compile-stage, symlink the
# Python binary in the venv to the system-wide Python, and add the venv to the PATH.
#
# Note that we symlink the Python binary in the venv to the system-wide Python so that
# any calls to `python3` will use our virtual environment. We are using short flags
# because the ln binary in Alpine Linux does not support long flags. The -f instructs
# ln to remove the existing file and the -s instructs ln to create a symbolic link.
###
COPY --from=compile-stage --chown=${CISA_USER}:${CISA_GROUP} ${VIRTUAL_ENV} ${VIRTUAL_ENV}
RUN ln -fs "$(command -v python3)" "${VIRTUAL_ENV}"/bin/python3
ENV PATH="${VIRTUAL_ENV}/bin:$PATH"

# Copy in the necessary files
COPY --chown=${CISA_USER}:${CISA_GROUP} src/update.sh src/email-update.py src/body.txt src/body.html ${CISA_HOME}/

###
# Prepare to run
###
WORKDIR ${CISA_HOME}
USER ${CISA_USER}:${CISA_GROUP}
ENTRYPOINT ["./update.sh"]
